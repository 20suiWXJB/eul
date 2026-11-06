//
//  DiskView.swift
//  eul
//
//  Created by Gao Sun on 2020/11/1.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import SwiftUI

struct DiskView: View {
    @EnvironmentObject var diskStore: DiskStore
    @EnvironmentObject var componentConfigStore: ComponentConfigStore
    @EnvironmentObject var textStore: ComponentsStore<DiskTextComponent>
    @EnvironmentObject var preferenceStore: PreferenceStore

    var config: EulComponentConfig {
        componentConfigStore[.Disk]
    }

    func u(_ s: String) -> String {
        preferenceStore.showStatusBarUnit ? s : s.droppingUnit
    }

    var texts: [String] {
        textStore.activeComponents.map {
            switch $0 {
            case .free:
                return u(diskStore.freeString)
            case .usage:
                return u(diskStore.usageString)
            case .total:
                return u(diskStore.totalString)
            case .usagePercentage:
                return u(diskStore.usagePercentageString)
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if config.showIcon {
                Image("Disk")
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
