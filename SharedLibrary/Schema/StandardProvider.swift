//
//  StandardProvider.swift
//  SharedLibrary
//
//  Created by Gao Sun on 2020/11/7.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import WidgetKit

@available(OSXApplicationExtension 11, *)
public protocol StandardProvider: TimelineProvider {
    associatedtype WidgetEntry: SharedWidgetEntry
}

@available(OSXApplicationExtension 11, *)
public extension StandardProvider {
    func placeholder(in _: Context) -> WidgetEntry {
        Container.get(WidgetEntry.self) ?? WidgetEntry.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(WidgetEntry.sample)
            return
        }

        let entry = Container.get(WidgetEntry.self) ?? WidgetEntry(outdated: true)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        completion(makeTimeline(at: Date()))
    }

    internal func makeTimeline(at currentDate: Date) -> Timeline<WidgetEntry> {
        guard Container.isSharedStorageAvailable else {
            return Timeline(entries: [WidgetEntry(outdated: true)], policy: .never)
        }
        let entry = Container.get(WidgetEntry.self) ?? WidgetEntry(outdated: true)
        var entries = [entry]
        if !entry.outdated, entry.expirationDate > currentDate {
            entries.append(WidgetEntry(date: entry.expirationDate, outdated: true))
        }
        return Timeline(entries: entries, policy: .after(currentDate.addingTimeInterval(10)))
    }
}
