//
//  InAppEventPushOrder.swift
//  Atlas
//

import Foundation

/// An event's images for a language the same push creates name that
/// language by its locale (`EventLocalizationPlaceholder`), so they wait
/// until everything else has gone, its texts included. The rest keep the
/// queue's order.
enum InAppEventPushOrder {
    static func sorted(_ changes: [PendingChange]) -> [PendingChange] {
        changes.filter { !waitsForANewLanguage($0) } + changes.filter(waitsForANewLanguage)
    }

    static func waitsForANewLanguage(_ change: PendingChange) -> Bool {
        change.requests.contains { EventLocalizationPlaceholder(in: $0) != nil }
    }
}
