//
//  CpuView.swift
//  eul
//
//  Created by Gao Sun on 2020/6/27.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import SwiftUI

struct CpuView: View {
    @EnvironmentObject var cpuStore: CpuStore
    @EnvironmentObject var componentConfigStore: ComponentConfigStore
    @EnvironmentObject var textStore: ComponentsStore<CpuTextComponent>
    @EnvironmentObject var preferenceStore: PreferenceStore

    var config: EulComponentConfig {
        componentConfigStore[.CPU]
    }

    func u(_ s: String) -> String {
        preferenceStore.showStatusBarUnit ? s : s.droppingUnit
    }

    var texts: [String] {
        textStore.activeComponents.map {
            switch $0 {
            case .usagePercentage:
                return u(cpuStore.usageString)
            case .temperature:
                return u(cpuStore.temp?.temperatureString ?? "N/A")
            case .loadAverage1Min:
                return cpuStore.loadAverage1MinString
            case .loadAverage5Min:
                return cpuStore.loadAverage5MinString
            case .loadAverage15Min:
                return cpuStore.loadAverage15MinString
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if config.showIcon {
                Image("CPU")
                    .resizable()
                    .frame(width: 13, height: 13)
            }
            if config.showGraph {
                LineChart(points: cpuStore.usageHistory)
            }
            if textStore.showComponents {
                StatusBarTextView(texts: texts)
                    .stableWidth()
            }
        }
    }
}
