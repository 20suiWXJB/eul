// Compiled with the production sources by run-regressions.py.
import Foundation
import Metal

func bytes(_ values: [UInt8]) -> SMCBytes {
    var result = SMCParamStruct().bytes
    withUnsafeMutableBytes(of: &result) { buffer in
        for (index, value) in values.enumerated() { buffer[index] = value }
    }
    return result
}

func floatBytes(_ value: Float) -> SMCBytes {
    var bits = value.bitPattern.littleEndian
    return withUnsafeBytes(of: &bits) { bytes(Array($0)) }
}

func expectThrow(_ operation: () throws -> Void) {
    do {
        try operation()
        fatalError("Expected an error")
    } catch {}
}

func checkRegressions() throws {
    precondition(MemoryLayout<SMCParamStruct>.stride == 80)
    precondition(MemoryLayout<SMCParamStruct>.offset(of: \.keyInfo) == 28)
    precondition(MemoryLayout<SMCParamStruct>.offset(of: \.result) == 40)
    precondition(MemoryLayout<SMCParamStruct>.offset(of: \.data32) == 44)
    precondition(MemoryLayout<SMCParamStruct>.offset(of: \.bytes) == 48)

    let float = try SMCKit.decodeNumber(floatBytes(48.25), info: DataTypes.FLT)
    let positive = try SMCKit.decodeNumber(bytes([0x30, 0x80]), info: DataTypes.SP78)
    let negative = try SMCKit.decodeNumber(bytes([0xF5, 0x80]), info: DataTypes.SP78)
    let fraction = try SMCKit.decodeNumber(bytes([0x01, 0x03]), info: DataTypes.FPE2)
    let stoppedFloat = try SMCKit.decodeNumber(floatBytes(0), info: DataTypes.FLT)
    let stoppedFPE2 = try SMCKit.decodeNumber(bytes([0, 0]), info: DataTypes.FPE2)
    precondition(float == 48.25 && positive == 48.5 && negative == -10.5)
    precondition(fraction == 64.75 && stoppedFloat == 0 && stoppedFPE2 == 0)
    expectThrow { _ = try SMCKit.decodeNumber(bytes([0]), info: DataTypes.UInt8) }
    expectThrow { _ = try SMCKit.decodeNumber(bytes([0]), info: DataType(type: DataTypes.FLT.type, size: 2)) }
    expectThrow { _ = try SMCKit.decodeNumber(floatBytes(.nan), info: DataTypes.FLT) }
    expectThrow { _ = try SMCKit.decodeNumber(floatBytes(.infinity), info: DataTypes.FLT) }

    let mappings = TemperatureSensors.appleSilicon(chip: "Apple M4 Pro")
    precondition(mappings.contains { $0.code.toString() == "Tp09" && $0.group == .cpu })
    precondition(mappings.contains { $0.code.toString() == "Tg0L" && $0.group == .gpu })
    precondition(mappings.contains { $0.code.toString() == "Tg1U" && $0.group == .gpu })
    precondition(mappings.contains { $0.code.toString() == "Tm0p" && $0.group == .memory })
    let sensor = TemperatureData(sensor: mappings[0], temp: 42)
    expectThrow {
        try sensor.refresh(unit: .celius) { _, _ in throw SMCKit.SMCError.invalidDataValue }
    }
    precondition(sensor.temp == nil)
    try sensor.refresh(unit: .fahrenheit) { _, unit in
        precondition(unit == .fahrenheit)
        return TemperatureUnit.toFahrenheit(float)
    }
    precondition(abs(sensor.temp! - 118.85) < 0.000001)

    let apple = GPU(deviceId: "123", model: "Apple GPU", vendor: "Apple", registryID: 123)
    let fixture: NSDictionary = ["eulRegistryID": UInt64(123), "PerformanceStatistics": ["Device Utilization %": 27]]
    let statistic = GPU.statistic(from: fixture)!
    precondition(statistic.pciMatch == nil && statistic.matches(apple))
    precondition(statistic.usagePercentage == 27 && statistic.temperature == nil && statistic.coreClock == nil && statistic.memoryClock == nil)
    precondition(!statistic.matches(GPU(deviceId: "124", registryID: 124)))
    let intel = GPU(deviceId: "0x1234")
    let pci: NSDictionary = ["IOPCIMatch": "0x12348086", "PerformanceStatistics": ["GPU Activity(%)": 0]]
    precondition(GPU.statistic(from: pci)!.matches(intel))
    precondition(GPU.statistic(from: ["PerformanceStatistics": [:]]) == nil)
    precondition(GPU.statistic(from: ["PerformanceStatistics": ["Device Utilization %": 101]]) == nil)
    precondition(GPU.statistic(from: ["PerformanceStatistics": ["Device Utilization %": Double.nan]]) == nil)
    let badTemperature: NSDictionary = ["PerformanceStatistics": ["Device Utilization %": 2, "Temperature(C)": Double.infinity]]
    precondition(GPU.statistic(from: badTemperature)!.temperature == nil)

    struct Entry: SharedEntry {
        static let containerKey = "regression"
        var value = 1
    }
    precondition(!Container.isSharedStorageAvailable && Container.defaults == nil)
    Container.set(Entry())
    precondition(Container.get(Entry.self) == nil)
    print("PASS: SMC layout/decoding, missing readings/recovery, sensor groups, GPU registry/PCI matching, Debug shared storage")
}

func probeHardware() throws {
    try SMCKit.open()
    defer { SMCKit.close() }
    for sensor in try SMCKit.allKnownTemperatureSensors() {
        do {
            let info = try SMCKit.keyInformation(sensor.code)
            let value = try SMCKit.temperature(sensor.code, unit: .celius)
            print("SENSOR", sensor.group, sensor.code.toString(), info.type.toString(), value)
        } catch { print("SENSOR unavailable", sensor.code.toString(), error) }
    }
    for id in 0..<(try SMCKit.fanCount()) {
        print("FAN", id, "current", try SMCKit.fanCurrentSpeed(id), "min", try SMCKit.fanMinSpeed(id), "max", try SMCKit.fanMaxSpeed(id))
    }
    for gpu in GPU.getGPUs() ?? [] {
        print("GPU", gpu.model ?? "N/A", "registryID", gpu.registryID ?? 0)
        for _ in 0..<5 {
            let value = GPU.getInfo()?.first { $0.matches(gpu) }
            print("GPU sample", value?.usagePercentage as Any, "temperature", value?.temperature as Any, "clock", value?.coreClock as Any)
            Thread.sleep(forTimeInterval: 1)
        }
    }
    if CommandLine.arguments.contains("--gpu-load") { try probeGPULoad() }
}

func probeGPULoad() throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
        fatalError("Metal unavailable")
    }
    let library = try device.makeLibrary(source: """
    #include <metal_stdlib>
    using namespace metal;
    kernel void work(device float *output [[buffer(0)]], uint id [[thread_position_in_grid]]) {
        float value = float(id) * 0.001;
        for (uint i = 0; i < 256; ++i) { value = sin(value) + 0.01; }
        output[id] = value;
    }
    """, options: nil)
    let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "work")!)
    let buffer = device.makeBuffer(length: 65536 * MemoryLayout<Float>.size)!
    let end = Date().addingTimeInterval(4)
    var nextSample = Date()
    while Date() < end {
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.dispatchThreads(MTLSize(width: 65536, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if Date() >= nextSample {
            print("GPU under Metal load", GPU.getInfo()?.map { $0.usagePercentage } as Any)
            nextSample = Date().addingTimeInterval(0.5)
        }
    }
}

try checkRegressions()
if CommandLine.arguments.contains("--hardware") { try probeHardware() }
