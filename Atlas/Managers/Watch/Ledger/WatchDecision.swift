//
//  WatchDecision.swift
//  Atlas
//

import Foundation

/// What the ledger decided for one finding on a check.
struct WatchDecision: Identifiable, Hashable, Sendable {
    enum Verdict: Hashable, Sendable {
        /// Goes in this app's run.
        case send
        /// Kept for Atlas's own lines; never sent to an assistant for now.
        case localOnly
        case skip(WatchSkipReason)

        /// "send", "localOnly", or the skip's reason, for the debug scene.
        var key: String {
            switch self {
            case .send: "send"
            case .localOnly: "localOnly"
            case let .skip(reason): reason.key
            }
        }
    }

    var signal: WatchSignal
    var verdict: Verdict

    var id: String { signal.id }

    var isSent: Bool { verdict == .send }
}
