//
//  PushTally.swift
//  Atlas
//

import Foundation

/// What a push's items came to as they finish: the apps that changed, why
/// each failed one failed, and why the rest stop, once something stops them.
struct PushTally {
    var pushedApps: Set<StoreApp.ID> = []
    var failures: [PendingChange.ID: String] = [:]
    var stopReason: String?

    mutating func add(_ outcome: PushItemOutcome, for id: PendingChange.ID) {
        switch outcome {
        case let .pushed(appID):
            pushedApps.insert(appID)
        case let .failed(text, stop):
            failures[id] = text
            stopReason = stop ?? stopReason
        case let .stopped(reason):
            stopReason = reason
        case .skipped:
            break
        }
    }
}
