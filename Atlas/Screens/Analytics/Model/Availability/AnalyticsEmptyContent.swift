//
//  AnalyticsEmptyContent.swift
//  Atlas
//

import Foundation

/// What an Analytics view says while it has nothing to show (README-DS
/// §14 and §16): the case's title, one or two sentences on Apple's rule
/// behind it, 2 or 3 facts as key/value lines, an optional small line on
/// what happens next, and at most one button. Made by
/// `subscriptions(_:appName:)` and `stability(_:appName:)`.
struct AnalyticsEmptyContent: Hashable, Sendable {
    var availability: AnalyticsTabAvailability
    var text: String
    var facts: [AnalyticsEmptyFact] = []
    var note: String?
    var action: AnalyticsEmptyAction?

    var title: String { availability.title }

    /// "Time zone" · "Pacific": every report's day is a Pacific day.
    static var pacificFact: AnalyticsEmptyFact {
        AnalyticsEmptyFact(
            label: String(localized: "Time zone", comment: "kind:label · Analytics empty state fact"),
            value: String(localized: "Pacific", comment: "kind:label · Analytics empty state fact, the reports' time zone")
        )
    }
}
