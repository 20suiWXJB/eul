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

    try checkWidgetSharing()
    print("PASS: SMC layout/decoding, missing readings/recovery, sensor groups, GPU registry/PCI matching")
}

struct RegressionProvider: StandardProvider {
    typealias WidgetEntry = MemoryEntry
}

func checkWidgetSharing() throws {
    precondition(Container.isSharedStorageAvailable)
    let defaults = Container.defaults!
    defer {
        defaults.removePersistentDomain(forName: regressionSuiteName)
        defaults.synchronize()
    }
    let provider = RegressionProvider()
    let now = Date()
    precondition(Container.get(MemoryEntry.self) == nil)
    let missing = provider.makeTimeline(at: now)
    precondition(missing.entries.count == 1 && missing.entries[0].outdated)
    precondition(missing.policy == .after(now.addingTimeInterval(10)))

    defaults.set(Data("invalid plist".utf8), forKey: MemoryEntry.containerKey)
    precondition(Container.get(MemoryEntry.self) == nil)
    precondition(provider.makeTimeline(at: now).entries[0].outdated)

    let entry = MemoryEntry(date: now.addingTimeInterval(-30), used: 10, total: 18, temp: 50)
    Container.set(entry)
    let decoded = Container.get(MemoryEntry.self)!
    precondition(decoded.date == entry.date && decoded.used == 10 && decoded.total == 18 && decoded.temp == 50)
    precondition(decoded.isValid)
    precondition(entry.expirationDate == now.addingTimeInterval(30))
    let timeline = provider.makeTimeline(at: now)
    precondition(timeline.entries.count == 2 && !timeline.entries[0].outdated)
    precondition(timeline.entries[1].outdated && timeline.entries[1].date == entry.expirationDate)
    precondition(timeline.policy == .after(now.addingTimeInterval(10)))
    precondition(provider.makeTimeline(at: entry.expirationDate).entries.count == 1)
    precondition(MemoryEntry(date: now.addingTimeInterval(-59), used: 10, total: 18).isValid)
    precondition(!MemoryEntry(date: now.addingTimeInterval(-60), used: 10, total: 18).isValid)
    precondition(!MemoryEntry(date: now.addingTimeInterval(-61), used: 10, total: 18).isValid)
    precondition(!MemoryEntry(date: now, outdated: true).isValid)

    defaults.synchronize()
    let reader = Process()
    reader.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    reader.arguments = ["--read-widget"]
    try reader.run()
    reader.waitUntilExit()
    precondition(reader.terminationStatus == 0)

    Container.set(MemoryEntry(date: now.addingTimeInterval(-61), used: 10, total: 18))
    let expired = provider.makeTimeline(at: now)
    precondition(expired.entries.count == 1 && !expired.entries[0].isValid)
    print("PASS: isolated Widget storage, Codable/cross-process reads, missing/corrupt data, 60-second expiry and timeline")
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

if CommandLine.arguments.contains("--read-widget") {
    let entry = Container.get(MemoryEntry.self)!
    precondition(entry.used == 10 && entry.total == 18 && entry.temp == 50 && entry.isValid)
    print("PASS: separate process read Widget data")
    exit(0)
}

try checkRegressions()
if CommandLine.arguments.contains("--hardware") { try probeHardware() }
