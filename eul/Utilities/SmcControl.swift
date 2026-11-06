//
//  SmcControl.swift
//  eul
//
//  Created by Gao Sun on 2020/6/27.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import Foundation
import SharedLibrary
import SwiftyJSON

class SmcControl: Refreshable {
    static var shared = SmcControl()

    var sensors: [TemperatureData] = []
    var fans: [FanData] = []
    var tempUnit: TemperatureUnit = .celius
    private var errors: [String: String] = [:]

    private func averageTemperature(_ group: TemperatureSensor.Group) -> Double? {
        let values = sensors.filter { $0.sensor.group == group }.compactMap { $0.temp }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var cpuDieTemperature: Double? {
        averageTemperature(.cpu) ?? sensors.first(where: { $0.sensor.name == "CPU_0_DIE" })?.temp
    }

    var cpuProximityTemperature: Double? {
        sensors.first(where: { $0.sensor.name == "CPU_0_PROXIMITY" })?.temp
    }

    var gpuProximityTemperature: Double? {
        averageTemperature(.gpu) ?? sensors.first(where: { $0.sensor.name == "GPU_0_PROXIMITY" })?.temp
    }

    var memoryProximityTemperature: Double? {
        averageTemperature(.memory) ?? sensors.first(where: { $0.sensor.name == "MEM_SLOTS_PROXIMITY" })?.temp
    }

    var isFanValid: Bool {
        fans.count > 0
    }

    func formatTemp(_ value: Double) -> String {
        value.formatTemp(unit: tempUnit)
    }

    init() {
        do {
            try SMCKit.open()
            sensors = try SMCKit.allKnownTemperatureSensors().map { .init(sensor: $0) }
        } catch {
            print("SMC init error", error)
            return
        }
        if let count = read("FNum", { try SMCKit.fanCount() }) {
            fans = (0..<count).map { id in
                FanData(id: id,
                        minSpeed: read("F\(id)Mn") { try SMCKit.fanMinSpeed(id) },
                        maxSpeed: read("F\(id)Mx") { try SMCKit.fanMaxSpeed(id) })
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func subscribe() {
        initObserver(for: .SMCShouldRefresh)
    }

    func close() {
        SMCKit.close()
    }

    @objc func refresh() {
        for sensor in sensors {
            _ = read(sensor.sensor.code.toString()) { try sensor.refresh(unit: tempUnit) }
        }
        fans = fans.map { fan in
            FanData(
                id: fan.id,
                currentSpeed: read("F\(fan.id)Ac") { try SMCKit.fanCurrentSpeed(fan.id) },
                minSpeed: fan.minSpeed,
                maxSpeed: fan.maxSpeed
            )
        }
        NotificationCenter.default.post(name: .StoreShouldRefresh, object: nil)
    }

    private func read<T>(_ key: String, _ operation: () throws -> T) -> T? {
        do {
            let value = try operation()
            if errors.removeValue(forKey: key) != nil { print("SMC recovered", key) }
            return value
        } catch {
            let message = String(describing: error)
            if errors[key] != message { print("SMC read error", key, message) }
            errors[key] = message
            return nil
        }
    }
}

extension TemperatureUnit {
    var description: String {
        switch self {
        case .celius:
            return "temp.celsius".localized()
        case .fahrenheit:
            return "temp.fahrenheit".localized()
        case .kelvin:
            return "temp.kelvin".localized()
        }
    }
}

extension Fan: JSONCodabble {
    init?(json: JSON) {
        guard
            let id = json["id"].int,
            let name = json["name"].string,
            let minSpeed = json["id"].int,
            let maxSpeed = json["id"].int
        else {
            return nil
        }
        self.id = id
        self.name = name
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
    }

    var json: JSON {
        JSON([
            "id": id,
            "name": name,
            "minSpeed": minSpeed,
            "maxSpeed": maxSpeed,
        ])
    }
}

extension Double {
    var temperatureString: String {
        SmcControl.shared.formatTemp(self)
    }
}
