//
//  InAppEventWhenText.swift
//  Atlas
//

import Foundation

/// The line the App Store shows under an event's name at the top of its
/// details page: "Starts Dec 1", "Now available" or "Ended"; "No dates
/// yet" for a draft without them. The event page's preview and the
/// full-size viewer both say it.
enum InAppEventWhenText {
    static func text(for event: InAppEvent, now: Date = .now) -> String {
        guard let start = event.schedule?.eventStart, let end = event.schedule?.eventEnd else { return String(localized: "No dates yet") }
        if event.state.isOver || end < now { return String(localized: "Ended") }
        if start <= now { return String(localized: "Now available") }
        return String(localized: "Starts \(start.formatted(.dateTime.month(.abbreviated).day()))")
    }
}
