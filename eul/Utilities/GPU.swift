//
//  GPU.swift
//  eul
//
//  Created by Gao Sun on 2021/1/23.
//  Copyright © 2021 Gao Sun. All rights reserved.
//

import Foundation
import IOKit

struct GPU: Identifiable {
    var deviceId: String
    var model: String?
    var vendor: String?
    var registryID: UInt64?

    var id: String {
        deviceId
    }
}

extension GPU {
    struct Statistic {
        var pciMatch: String?
        var usagePercentage: Int
        var temperature: Double?
        var coreClock: Int?
        var memoryClock: Int?
        var registryID: UInt64?

        func matches(_ gpu: GPU) -> Bool {
            if let registryID = gpu.registryID { return self.registryID == registryID }
            guard let pciMatch = pciMatch else { return false }
            return pciMatch.lowercased().contains(gpu.deviceId.lowercased().deletingPrefix("0x"))
        }
    }
}

extension GPU {
    static func getGPUs() -> [GPU]? {
        #if arch(arm64)
            return IOHelper.getPropertyList(for: kIOAcceleratorClassName)?.compactMap { properties in
                guard let registryID = properties["eulRegistryID"] as? UInt64 else { return nil }
                let model: String?
                if let data = properties["model"] as? Data {
                    model = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
                } else {
                    model = properties["model"] as? String
                }
                return GPU(deviceId: String(registryID), model: model ?? "Apple GPU", vendor: "Apple", registryID: registryID)
            }
        #else
            guard let data = shellData(["system_profiler SPDisplaysDataType -xml"]) else {
                return nil
            }

            let pListDecoder = PropertyListDecoder()
            guard let plistArray = try? pListDecoder.decode(SystemProfilerPlistArray.self, from: data) else {
                return nil
            }

            return plistArray.first?.items.compactMap {
                guard $0.isGPU, let deviceId = $0.deviceId else {
                    return nil
                }
                return GPU(deviceId: deviceId, model: $0.model, vendor: $0.vendor)
            }
        #endif
    }

    static func statistic(from properties: NSDictionary) -> Statistic? {
        guard
            let statistics = properties["PerformanceStatistics"] as? [String: Any],
            let usage = statistics["Device Utilization %"] as? NSNumber ?? statistics["GPU Activity(%)"] as? NSNumber,
            usage.doubleValue.isFinite, (0...100).contains(usage.doubleValue)
        else { return nil }

        let rawTemperature = (statistics["Temperature(C)"] as? NSNumber)?.doubleValue
        let temperature = rawTemperature.flatMap { $0.isFinite && (-50...150).contains($0) ? $0 : nil }
        return Statistic(
            pciMatch: properties["IOPCIMatch"] as? String ?? properties["IOPCIPrimaryMatch"] as? String,
            usagePercentage: usage.intValue,
            temperature: temperature,
            coreClock: statistics["Core Clock(MHz)"] as? Int,
            memoryClock: statistics["Memory Clock(MHz)"] as? Int,
            registryID: properties["eulRegistryID"] as? UInt64
        )
    }

    // https://stackoverflow.com/questions/10110658/programmatically-get-gpu-percent-usage-in-os-x/22440235#22440235
    // https://github.com/exelban/stats/blob/master/Modules/GPU/reader.swift
    static func getInfo() -> [Statistic]? {
        guard let propertyList = IOHelper.getPropertyList(for: kIOAcceleratorClassName) else {
            return nil
        }

        return propertyList.compactMap { properties in
            guard var value = statistic(from: properties) else { return nil }
            if let celsius = value.temperature {
                switch SmcControl.shared.tempUnit {
                case .celius: break
                case .fahrenheit: value.temperature = (celsius * 1.8) + 32
                case .kelvin: value.temperature = celsius + 273.15
                }
            }
            value.temperature = value.temperature ?? SmcControl.shared.gpuProximityTemperature
            return value
        }
    }
}
