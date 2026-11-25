//
//  WatchDedupe.swift
//  Atlas
//

import Foundation

/// What Atlas already shows for the findings elsewhere: a suggestion or an
/// assistant's finding waiting for the person, or one the person turned
/// down. A finding with either isn't sent again.
struct WatchDedupe: Hashable, Sendable {
    /// Identities with something waiting for the person.
    var waiting: Set<String> = []
    /// Identities the person turned down somewhere else.
    var dismissed: Set<String> = []

    /// How long a dismissed What's New suggestion keeps the finding away.
    static let dismissalMemory: TimeInterval = 7 * 24 * 3600

    func reason(for signal: WatchSignal) -> WatchSkipReason? {
        if dismissed.contains(signal.identity) { return .dismissedElsewhere }
        if waiting.contains(signal.identity) { return .alreadySuggested }
        return nil
    }

    /// From the app's suggestions and Analytics findings: a dismissed
    /// "stability.crashes.<version>" finding or an assistant's open one on
    /// Stability for a crash finding; a What's New suggestion dismissed in
    /// the last week for a What's New one.
    @MainActor
    static func make(
        for signals: [WatchSignal], appID: StoreApp.ID, suggestions: FieldSuggestionStore?, findings: AnalyticsFindingsState, now: Date
    ) -> WatchDedupe {
        var dedupe = WatchDedupe()
        for signal in signals {
            switch signal.kind {
            case .crashesWorse:
                if findings.dismissed.contains(where: { $0.id == "stability.crashes.\(signal.subject)" }) { dedupe.dismissed.insert(signal.identity) }
                if findings.open.contains(where: { $0.source != .builtIn && $0.area == .stability }) { dedupe.waiting.insert(signal.identity) }
            case .whatsNewMissing:
                let turnedDown = suggestions?.all(for: appID, area: .storePage).contains { suggestion in
                    suggestion.target.field == ListingField.whatsNew.rawValue && suggestions?.isDismissed(suggestion) == true
                        && now.timeIntervalSince(suggestion.createdAt) < dismissalMemory
                } ?? false
                if turnedDown { dedupe.dismissed.insert(signal.identity) }
            case .eventDeadline, .reviewsAfterRelease, .submissionBlocked, .versionRejected:
                // Their detectors already leave out what's suggested or grouped.
                break
            }
        }
        return dedupe
    }
}
