//
//  FanView.swift
//  eul
//
//  Created by Gao Sun on 2020/6/27.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import SwiftUI

struct FanView: View {
    @EnvironmentObject var fanStore: FanStore
    @EnvironmentObject var componentConfigStore: ComponentConfigStore
    @EnvironmentObject var textStore: ComponentsStore<FanTextComponent>
    @EnvironmentObject var preferenceStore: PreferenceStore

    var config: EulComponentConfig {
        componentConfigStore[.Fan]
    }

    func u(_ s: String) -> String {
        preferenceStore.showStatusBarUnit ? s : s.droppingUnit
    }

    var averageRpm: String {
        let speeds = fanStore.fans.compactMap { $0.currentSpeed }
        return "\(speeds.reduce(0) { $0 + $1 } / speeds.count) rpm"
    }

    var texts: [String] {
        textStore.activeComponents.compactMap { component in
            if component.isAverage {
                return u(averageRpm)
            }
            guard let fan = fanStore.fans.first(where: { $0.id == component.id }) else {
                return nil
            }
            return u(fan.currentSpeedString)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if config.showIcon {
                Image("Fan")
                    .resizable()
                    .frame(width: 13, height: 13)
            }
            if textStore.showComponents {
                StatusBarTextView(texts: texts)
                    .stableWidth()
            }
        }
    }
}
