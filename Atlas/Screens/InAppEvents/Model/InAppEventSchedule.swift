//
//  InAppEventSchedule.swift
//  Atlas
//

import Foundation

/// When an event runs and from when its card shows, in the territories it
/// applies to.
struct InAppEventSchedule: Hashable, Codable, Sendable {
    /// Alpha-3 territory ids; empty means everywhere.
    var territories: [String] = []
    /// From when the card shows on the App Store.
    var publishStart: Date?
    var eventStart: Date?
    var eventEnd: Date?
}
