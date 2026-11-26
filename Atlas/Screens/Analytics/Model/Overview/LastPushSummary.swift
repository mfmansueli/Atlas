//
//  LastPushSummary.swift
//  Atlas
//

import Foundation

/// The Overview's "Last push" (board 92): the newest push from Atlas, what
/// it moved, and its verdict, "New subtitle · English" · "Pushed Oct 2 ·
/// tap-through from search 1.9% → 2.3%" · Better.
struct LastPushSummary: Hashable, Sendable {
    var changeID: MeasuredChange.ID
    var title: String
    var detail: String
    /// "Better", "Day 20 of 28", "Too few to tell".
    var status: String
    /// The pill's colour; nil keeps it grey.
    var verdict: FunnelVerdict?

    /// The newest of `changes`; nil before the first push.
    static func make(changes: [MeasuredChange], results: [MeasuredChange.ID: ChangeResult]) -> LastPushSummary? {
        guard let change = changes.max(by: { $0.date < $1.date }) else { return nil }
        let pushed = String(localized: "Pushed \(AnalyticsText.day(change.date))", comment: "kind:label · Analytics Overview: Last push")
        guard let result = results[change.id] else {
            return LastPushSummary(
                changeID: change.id, title: change.title, detail: pushed,
                status: String(localized: "Not measured yet", comment: "kind:pill · Analytics Overview: Last push")
            )
        }
        let moved = "\(change.stageTitle.localizedLowercase) \(result.beforeAfterText)"
        switch result.state {
        case .noBefore:
            return LastPushSummary(changeID: change.id, title: change.title, detail: pushed, status: result.statusText)
        case .measuring:
            return LastPushSummary(changeID: change.id, title: change.title, detail: "\(pushed) · \(moved)", status: result.statusText)
        case .final:
            let outcome = result.main.comparison.outcome
            let verdict = FunnelVerdict(outcome)
            return LastPushSummary(
                changeID: change.id, title: change.title, detail: "\(pushed) · \(moved)", status: verdict?.title ?? outcome.title, verdict: verdict
            )
        }
    }

    var accessibilityText: String {
        "\(title). \(detail). \(status)"
    }
}
