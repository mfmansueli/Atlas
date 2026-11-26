//
//  AnalyticsTabSummary.swift
//  Atlas
//

import Foundation

/// The short line under each view's name in Analytics' card strip (board
/// 92): "Fewer page views · crashes up" (amber), "3 new to try", "5 pushes
/// · 1 better", "1,284 subscribers", "Crashes 3.2× on 1.4". A view with no
/// data yet says its case instead ("None sold yet").
struct AnalyticsTabSummary: Hashable, Sendable {
    var text: String
    var tone: PageCardTone = .neutral

    /// What the view model already worked out, which the lines are made
    /// from.
    struct Inputs: Hashable, Sendable {
        var funnel: FunnelReport?
        var stability: StabilityReport?
        var newFindings = 0
        var openFindings = 0
        /// Pushes from Atlas measured in After Changes, and how many of
        /// them came out better.
        var pushes = 0
        var betterPushes = 0
        var activeSubscribers: Int?
    }

    static func make(_ tab: AnalyticsTab, availability: AnalyticsTabAvailability = .available, inputs: Inputs) -> AnalyticsTabSummary {
        guard availability.isAvailable else { return AnalyticsTabSummary(text: availability.cardSummary) }
        switch tab {
        case .overview:
            return overview(inputs)
        case .breakDown:
            return AnalyticsTabSummary(text: String(localized: "Country, language, source…", comment: "kind:card-summary · Analytics strip, Break It Down"))
        case .whatToTry:
            return whatToTry(new: inputs.newFindings, open: inputs.openFindings)
        case .afterChanges:
            return afterChanges(pushes: inputs.pushes, better: inputs.betterPushes)
        case .subscriptions:
            return subscriptions(inputs.activeSubscribers)
        case .stability:
            return stability(inputs.stability)
        }
    }

    /// The step that fell, and crashes when the newest version is worse.
    private static func overview(_ inputs: Inputs) -> AnalyticsTabSummary {
        guard let funnel = inputs.funnel else { return AnalyticsTabSummary(text: "") }
        if case .tooFew = funnel.callout.kind {
            return AnalyticsTabSummary(text: String(localized: "Too few to tell", comment: "kind:card-summary · Analytics strip, Overview"))
        }
        if funnel.isNew {
            let since = AnalyticsText.day(funnel.period.first.date)
            return AnalyticsTabSummary(text: String(localized: "Since \(since)", comment: "kind:card-summary · Analytics strip, Overview of a new app"))
        }
        var parts: [String] = []
        if let worst = funnel.worstStep { parts.append(fewer(worst.stage)) }
        if inputs.stability?.isWorse == true {
            parts.append(parts.isEmpty
                ? String(localized: "Crashes up", comment: "kind:card-summary · Analytics strip, Overview")
                : String(localized: "crashes up", comment: "kind:card-summary · Analytics strip, Overview, after a step that fell"))
        }
        guard parts.isEmpty else { return AnalyticsTabSummary(text: parts.joined(separator: " · "), tone: .warning) }
        return AnalyticsTabSummary(text: String(localized: "No step worse than before", comment: "kind:card-summary · Analytics strip, Overview"))
    }

    /// "Fewer page views": the step whose rate fell most surely.
    static func fewer(_ stage: FunnelStage) -> String {
        switch stage {
        case .impressions: String(localized: "Fewer impressions", comment: "kind:card-summary · Analytics strip")
        case .pageViews: String(localized: "Fewer page views", comment: "kind:card-summary · Analytics strip")
        case .downloads: String(localized: "Fewer downloads", comment: "kind:card-summary · Analytics strip")
        case .trials: String(localized: "Fewer trials", comment: "kind:card-summary · Analytics strip")
        case .paid: String(localized: "Fewer paid starts", comment: "kind:card-summary · Analytics strip")
        }
    }

    private static func whatToTry(new: Int, open: Int) -> AnalyticsTabSummary {
        if new > 0 {
            return AnalyticsTabSummary(text: String(localized: "\(new) new to try", comment: "kind:card-summary · Analytics strip, What to Try"))
        }
        if open > 0 {
            return AnalyticsTabSummary(text: String(localized: "\(open) to try", comment: "kind:card-summary · Analytics strip, What to Try"))
        }
        return AnalyticsTabSummary(text: String(localized: "Nothing yet", comment: "kind:card-summary · Analytics strip, What to Try"))
    }

    private static func afterChanges(pushes: Int, better: Int) -> AnalyticsTabSummary {
        guard pushes > 0 else {
            return AnalyticsTabSummary(text: String(localized: "No pushes yet", comment: "kind:card-summary · Analytics strip, After Changes"))
        }
        let count = pushes == 1
            ? String(localized: "1 push", comment: "kind:card-summary · Analytics strip, After Changes")
            : String(localized: "\(pushes) pushes", comment: "kind:card-summary · Analytics strip, After Changes")
        guard better > 0 else { return AnalyticsTabSummary(text: count) }
        let improved = String(localized: "\(better) better", comment: "kind:card-summary · Analytics strip, After Changes: pushes that came out better")
        return AnalyticsTabSummary(text: "\(count) · \(improved)")
    }

    private static func subscriptions(_ active: Int?) -> AnalyticsTabSummary {
        guard let active else {
            return AnalyticsTabSummary(text: String(localized: "Trials and renewals", comment: "kind:card-summary · Analytics strip, Subscriptions"))
        }
        let text = active == 1
            ? String(localized: "1 subscriber", comment: "kind:card-summary · Analytics strip, Subscriptions")
            : String(localized: "\(AnalyticsText.count(active)) subscribers", comment: "kind:card-summary · Analytics strip, Subscriptions")
        return AnalyticsTabSummary(text: text)
    }

    private static func stability(_ report: StabilityReport?) -> AnalyticsTabSummary {
        guard let report else {
            return AnalyticsTabSummary(text: String(localized: "No crashes reported", comment: "kind:card-summary · Analytics strip, Stability"))
        }
        let version = report.latest.version
        if report.isWorse, let times = report.times {
            let text = String(localized: "Crashes \(AnalyticsText.times(times)) on \(version)", comment: "kind:card-summary · Analytics strip, Stability")
            return AnalyticsTabSummary(text: text, tone: .warning)
        }
        if report.hasSessions, report.comparison.isLower {
            return AnalyticsTabSummary(text: String(localized: "Fewer crashes on \(version)", comment: "kind:card-summary · Analytics strip, Stability"))
        }
        return AnalyticsTabSummary(text: String(localized: "Steady on \(version)", comment: "kind:card-summary · Analytics strip, Stability"))
    }
}
