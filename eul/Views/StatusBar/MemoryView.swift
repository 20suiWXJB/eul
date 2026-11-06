//
//  MemoryView.swift
//  eul
//
//  Created by Gao Sun on 2020/6/29.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var memoryStore: MemoryStore
    @EnvironmentObject var componentConfigStore: ComponentConfigStore
    @EnvironmentObject var textStore: ComponentsStore<MemoryTextComponent>
    @EnvironmentObject var preferenceStore: PreferenceStore

    var config: EulComponentConfig {
        componentConfigStore[.Memory]
    }

    func u(_ s: String) -> String {
        preferenceStore.showStatusBarUnit ? s : s.droppingUnit
    }

    var texts: [String] {
        textStore.activeComponents.map {
            switch $0 {
            case .free:
                return u(memoryStore.freeString)
            case .usage:
                return u(memoryStore.usedString)
            case .total:
                return u(memoryStore.total.memoryString)
            case .usagePercentage:
                return u(memoryStore.usedPercentageString)
            case .temperature:
                return u(memoryStore.temp?.temperatureString ?? "N/A")
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if config.showIcon {
                Image("Memory")
                    .resizable()
                    .frame(width: 13, height: 13)
            }
            if config.showGraph {
                LineChart(points: memoryStore.usageHistory)
            }
            if textStore.showComponents {
                StatusBarTextView(texts: texts)
                    .stableWidth()
            }
        }
    }
}
