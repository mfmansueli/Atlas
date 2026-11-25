//
//  WatchPlan.swift
//  Atlas
//

import Foundation

/// What one check of Look for Improvements found and decided, app by app:
/// the findings, what the ledger let through, why no run starts (or the
/// prompt the run starts with). The debug scene shows it as it is.
struct WatchPlan: Hashable, Sendable {
    struct App: Identifiable, Hashable, Sendable {
        var appID: StoreApp.ID
        var appName: String
        var decisions: [WatchDecision]
        /// Why no run starts for it; nil when one does, or nothing is sent.
        var refusal: WatchBudgetRefusal?
        /// What the run starts with; nil when none starts.
        var prompt: String?

        var id: StoreApp.ID { appID }

        var signals: [WatchSignal] { decisions.map(\.signal) }

        /// What the run takes.
        var toSend: [WatchSignal] { decisions.filter(\.isSent).map(\.signal) }

        var startsRun: Bool { prompt != nil }
    }

    var date: Date
    var apps: [App] = []
}
