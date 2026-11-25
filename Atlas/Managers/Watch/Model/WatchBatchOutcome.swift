//
//  WatchBatchOutcome.swift
//  Atlas
//

import Foundation

/// One run's findings of one kind, and what the person made of them.
struct WatchBatchOutcome: Hashable, Codable, Sendable {
    var runID: UUID
    var accepted = 0
    var edited = 0
    var dismissed = 0
    var ignored = 0

    init(runID: UUID, outcomes: [WatchSignalOutcome] = []) {
        self.runID = runID
        for outcome in outcomes {
            switch outcome {
            case .accepted: accepted += 1
            case .edited: edited += 1
            case .dismissed: dismissed += 1
            case .ignored: ignored += 1
            }
        }
    }

    var total: Int { accepted + edited + dismissed + ignored }

    /// Accepted as sent or after an edit.
    var taken: Int { accepted + edited }
}
