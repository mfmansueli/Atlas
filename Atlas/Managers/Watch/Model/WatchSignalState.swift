//
//  WatchSignalState.swift
//  Atlas
//

import Foundation

/// Where one finding stands with the person.
enum WatchSignalState: Hashable, Codable, Sendable {
    /// Found, not sent to an assistant yet.
    case new
    /// Sent in Look for Improvements run `runID`.
    case sent(runID: UUID, date: Date)
    /// The person took what came of it.
    case accepted(date: Date)
    /// The person turned it down: it comes back only when its number moves
    /// a lot.
    case dismissed(date: Date)
    /// Not Now: it waits until then.
    case snoozed(until: Date)

    /// "new", "sent", "accepted", "dismissed", "snoozed", for the debug scene.
    var key: String {
        switch self {
        case .new: "new"
        case .sent: "sent"
        case .accepted: "accepted"
        case .dismissed: "dismissed"
        case .snoozed: "snoozed"
        }
    }
}
