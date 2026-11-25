//
//  WatchSkipReason.swift
//  Atlas
//

import Foundation

/// Why a finding isn't sent to the assistant this time.
enum WatchSkipReason: Hashable, Sendable {
    /// Don't Suggest This Again, for its kind in this app.
    case silenced
    /// Its kind is paused after three dismissals in a row.
    case paused
    /// The person accepted it, and its number hasn't moved much since.
    case accepted
    /// The person dismissed it, and its number hasn't moved much since.
    case dismissed
    /// Not Now, until then.
    case snoozed(until: Date)
    /// A run already has it, and it's still waiting for the person.
    case alreadySent
    /// Its kind came up for this app lately; backoff waits until then.
    case notDue(until: Date)
    /// A suggestion or finding for it already waits for the person.
    case alreadySuggested
    /// The person turned down what Atlas already showed for it.
    case dismissedElsewhere

    /// "silenced", "notDue"…, for the debug scene.
    var key: String {
        switch self {
        case .silenced: "silenced"
        case .paused: "paused"
        case .accepted: "accepted"
        case .dismissed: "dismissed"
        case .snoozed: "snoozed"
        case .alreadySent: "alreadySent"
        case .notDue: "notDue"
        case .alreadySuggested: "alreadySuggested"
        case .dismissedElsewhere: "dismissedElsewhere"
        }
    }
}
