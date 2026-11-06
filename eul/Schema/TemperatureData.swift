//
//  TemperatureData.swift
//  eul
//
//  Created by Gao Sun on 2020/12/1.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import Foundation
import SharedLibrary

class TemperatureData {
    let sensor: TemperatureSensor
    var temp: Double?

    init(sensor: TemperatureSensor, temp: Double? = nil) {
        self.sensor = sensor
        self.temp = temp
    }

    func refresh(unit: TemperatureUnit, read: (FourCharCode, TemperatureUnit) throws -> Double = SMCKit.temperature) throws {
        do {
            temp = try read(sensor.code, unit)
        } catch {
            temp = nil
            throw error
        }
    }
}
