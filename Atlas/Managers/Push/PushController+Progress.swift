//
//  PushController+Progress.swift
//  Atlas
//

import Foundation

/// How far a push got: counts, the bar and the sheet's title and subtitle.
extension PushController {
    var totalCount: Int { items.count }
    var doneCount: Int { items.count { $0.status == .done } }
    var failedCount: Int { items.count { $0.status.isFailure } }
    var finishedCount: Int { items.count { $0.status.isFinished } }
    var progress: Double { items.isEmpty ? 0 : Double(finishedCount) / Double(items.count) }
    var isRunning: Bool { phase == .running }
    /// Whether this push changed prices, so "View Results" applies.
    var changedPrices: Bool {
        items.contains { $0.status == .done && $0.change.section == .subscriptionPricing }
    }

    var title: String {
        switch phase {
        case .idle, .running:
            return totalCount == 1 ? String(localized: "Pushing 1 change") : String(localized: "Pushing \(totalCount) changes")
        case .finished:
            guard failedCount > 0 else { return String(localized: "\(doneCount) pushed") }
            return String(localized: "\(doneCount) pushed · \(failedCount) failed")
        }
    }

    var subtitle: String {
        switch phase {
        case .idle, .running:
            let sent = String(localized: "\(finishedCount) of \(totalCount) sent")
            let failed = failedCount > 0 ? String(localized: " · \(failedCount) failed") : ""
            return sent + failed + String(localized: " · up to \(PushSchedule.concurrentChanges) at once")
        case .finished:
            if failedCount > 0 { return String(localized: "Failed changes stay here. Retry them or fix them first.") }
            let notSent = items.count { !$0.status.isFailure && $0.status != .done }
            if notSent > 0 { return String(localized: "\(notSent) not sent. They stay in Review & Push.") }
            return String(localized: "Everything reached App Store Connect.")
        }
    }
}
