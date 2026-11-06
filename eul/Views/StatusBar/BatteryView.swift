//
//  BatteryView.swift
//  eul
//
//  Created by Gao Sun on 2020/8/7.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import SharedLibrary
import SwiftUI

struct BatteryView: View {
    @EnvironmentObject var batteryStore: BatteryStore
    @EnvironmentObject var componentConfigStore: ComponentConfigStore
    @EnvironmentObject var textStore: ComponentsStore<BatteryTextComponent>
    @EnvironmentObject var preferenceStore: PreferenceStore

    var config: EulComponentConfig {
        componentConfigStore[.Battery]
    }

    func u(_ s: String) -> String {
        preferenceStore.showStatusBarUnit ? s : s.droppingUnit
    }

    var texts: [String] {
        textStore.activeComponents.map {
            switch $0 {
            case .percentage:
                return u(batteryStore.charge.percentageString)
            case .mah:
                return u("\(batteryStore.capacity) mAh")
            case .timeRemaining:
                return batteryStore.timeRemaining
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if config.showIcon {
                BatteryIconView(
                    isCharging: batteryStore.io.isCharging,
                    charge: batteryStore.charge,
                    acPowered: batteryStore.acPowered
                )
            }
            if textStore.showComponents {
                StatusBarTextView(texts: texts)
                    .stableWidth()
            }
        }
    }
}
