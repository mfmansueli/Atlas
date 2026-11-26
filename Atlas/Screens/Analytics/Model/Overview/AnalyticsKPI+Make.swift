//
//  AnalyticsKPI+Make.swift
//  Atlas
//

import Foundation

extension AnalyticsKPI {
    /// What the four numbers are made from.
    struct Inputs: Hashable, Sendable {
        var rating: OverviewRating?
        var isRatingLoading = false
        var funnel: FunnelReport?
        var sellsSubscriptions = true
        /// Why sales are missing, when they are (the Paid step's gap).
        var salesGap: FunnelGap?
        var subscriptions: SubscriptionsReport?
        var subscriptionsAvailability: AnalyticsTabAvailability = .available
        var stability: StabilityReport?
        var stabilityAvailability: AnalyticsTabAvailability = .available
        /// Whether the strip has Stability, for the Crashes link.
        var hasStabilityTab = false
    }

    /// Rating, Proceeds, Active subscribers and Crashes; an app without a
    /// subscription has no proceeds or subscribers here.
    static func make(_ inputs: Inputs) -> [AnalyticsKPI] {
        var numbers = [rating(inputs.rating, isLoading: inputs.isRatingLoading)]
        if inputs.sellsSubscriptions {
            numbers.append(proceeds(inputs.funnel, gap: inputs.salesGap, availability: inputs.subscriptionsAvailability))
            numbers.append(subscribers(inputs.subscriptions, gap: inputs.salesGap, availability: inputs.subscriptionsAvailability))
        }
        numbers.append(crashes(inputs.stability, availability: inputs.stabilityAvailability, hasTab: inputs.hasStabilityTab))
        return numbers
    }

    // MARK: - Rating

    static func rating(_ rating: OverviewRating?, isLoading: Bool) -> AnalyticsKPI {
        let title = String(localized: "Rating", comment: "kind:label · Analytics Overview number")
        let link = String(localized: "Reviews", comment: "kind:button · Analytics Overview: opens Ratings & Reviews")
        if isLoading {
            return AnalyticsKPI(kind: .rating, title: title, value: "—", link: link, accessibilityText: title, isLoading: true)
        }
        guard let rating, let average = rating.average else {
            return AnalyticsKPI(
                kind: .rating, title: title, value: "—",
                detail: String(localized: "No ratings yet", comment: "kind:label · Analytics Overview number"), link: link,
                accessibilityText: opening(String(localized: "Rating: no ratings yet", comment: "kind:accessibility-label"), link)
            )
        }
        return AnalyticsKPI(
            kind: .rating, title: title, value: RatingsSummary.starsText(average),
            detail: rating.versionsText ?? String(localized: "All versions", comment: "kind:label · Analytics Overview: the rating of every version"),
            tone: rating.isLower ? .warning : .neutral, link: link,
            accessibilityText: opening(rating.accessibilityText, link)
        )
    }

    // MARK: - Proceeds

    static func proceeds(_ funnel: FunnelReport?, gap: FunnelGap?, availability: AnalyticsTabAvailability) -> AnalyticsKPI {
        let title = String(localized: "Proceeds", comment: "kind:label · Analytics Overview number")
        let link = String(localized: "By Country", comment: "kind:button · Analytics Overview: proceeds by country")
        if let gap { return missing(.proceeds, title: title, detail: gap.text, tone: gap.isProblem ? .warning : .neutral, link: nil) }
        if case .noSubscriptionsSold = availability { return missing(.proceeds, title: title, detail: availability.cardSummary, link: nil) }
        guard let funnel, let proceeds = funnel.totals.proceeds else {
            return missing(.proceeds, title: title, detail: notReported, link: nil)
        }
        let amount = AnalyticsText.dollars(proceeds)
        let change = AnalyticsText.change(whole(proceeds), from: funnel.previousTotals?.proceeds.map { whole($0) })
        let commission = String(localized: "after Apple’s commission", comment: "kind:label · Analytics Overview: proceeds")
        let detail = [change, commission].compactMap(\.self).joined(separator: " · ")
        let spoken = change.map { String(localized: "Proceeds \(amount), \($0) against the previous period", comment: "kind:accessibility-label") }
            ?? String(localized: "Proceeds \(amount)", comment: "kind:accessibility-label")
        return AnalyticsKPI(
            kind: .proceeds, title: title, value: amount, detail: detail, link: link,
            accessibilityText: spoken + ". " + String(localized: "See them by country", comment: "kind:accessibility-hint")
        )
    }

    // MARK: - Subscribers

    static func subscribers(_ report: SubscriptionsReport?, gap: FunnelGap?, availability: AnalyticsTabAvailability) -> AnalyticsKPI {
        let title = String(localized: "Active subscribers", comment: "kind:label · Analytics Overview number")
        let link = String(localized: "Subscriptions", comment: "kind:button · Analytics Overview: opens Subscriptions")
        if let gap { return missing(.subscribers, title: title, detail: gap.text, tone: gap.isProblem ? .warning : .neutral, link: nil) }
        switch availability {
        case .available:
            break
        case let .tooFewSubscribers(count):
            let value = AnalyticsText.count(count)
            return AnalyticsKPI(
                kind: .subscribers, title: title, value: value, detail: availability.cardSummary, link: link,
                accessibilityText: opening("\(title) \(value), \(availability.cardSummary)", link)
            )
        default:
            return missing(.subscribers, title: title, detail: availability.cardSummary, link: link)
        }
        guard let active = report?.active else { return missing(.subscribers, title: title, detail: notReported, link: link) }
        let value = AnalyticsText.count(active)
        let change = report?.activeChange
        let detail = change.map { String(localized: "\($0) vs before", comment: "kind:label · a count against the previous period") }
        let spoken = change.map { String(localized: "Active subscribers \(value), \($0) against before", comment: "kind:accessibility-label") }
            ?? String(localized: "Active subscribers \(value)", comment: "kind:accessibility-label")
        return AnalyticsKPI(kind: .subscribers, title: title, value: value, detail: detail, link: link, accessibilityText: opening(spoken, link))
    }

    // MARK: - Crashes

    static func crashes(_ report: StabilityReport?, availability: AnalyticsTabAvailability, hasTab: Bool) -> AnalyticsKPI {
        let link = hasTab ? String(localized: "Stability", comment: "kind:button · Analytics Overview: opens Stability") : nil
        let generic = String(localized: "Crashes", comment: "kind:label · Analytics Overview number")
        switch availability {
        case .available:
            break
        case let .versionTooNew(version, previous, previousRate):
            let title = crashesTitle(version)
            let tooNew = String(localized: "Too new to tell", comment: "kind:label · Analytics Overview: crashes of a new version")
            let detail = if let previous, let previousRate {
                tooNew + " · " + String(
                    localized: "\(previous) had \(AnalyticsText.perThousand(previousRate))",
                    comment: "kind:label · the previous version's crashes per 1,000 sessions"
                )
            } else {
                tooNew
            }
            let spoken = String(localized: "Crashes on version \(version): too new to tell", comment: "kind:accessibility-label")
            return AnalyticsKPI(kind: .crashes, title: title, value: "—", detail: detail, link: link, accessibilityText: opening(spoken, link))
        default:
            return missing(.crashes, title: report.map { crashesTitle($0.latest.version) } ?? generic, detail: availability.cardSummary, link: link)
        }
        guard let report else { return missing(.crashes, title: generic, detail: notReported, link: link) }
        let title = crashesTitle(report.latest.version)
        guard report.hasSessions, let rate = report.latest.perThousand else {
            let count = AnalyticsText.count(report.latest.crashes)
            return AnalyticsKPI(
                kind: .crashes, title: title, value: count,
                detail: String(localized: "crashes · no sessions for a rate", comment: "kind:label · Analytics Overview: crashes without sessions"),
                link: link, accessibilityText: opening("\(title): \(count)", link)
            )
        }
        let value = AnalyticsText.perThousand(rate)
        let perThousand = String(localized: "per 1,000 sessions", comment: "kind:label · Analytics Overview: crash rate")
        var detail = perThousand
        var spoken = String(localized: "Crashes on version \(report.latest.version): \(value) per 1,000 sessions", comment: "kind:accessibility-label")
        if let previous = report.previous, let times = report.times {
            detail = "\(AnalyticsText.times(times)) \(previous.version) · \(perThousand)"
            spoken += ", " + String(
                localized: "\(AnalyticsText.times(times)) version \(previous.version)",
                comment: "kind:accessibility-label · how many times the previous version's crash rate"
            )
        }
        return AnalyticsKPI(
            kind: .crashes, title: title, value: value, detail: detail, tone: report.isWorse ? .warning : .neutral, link: link,
            accessibilityText: opening(spoken, link)
        )
    }

    // MARK: - Helpers

    /// "Crashes on 1.4".
    static func crashesTitle(_ version: String) -> String {
        String(localized: "Crashes on \(version)", comment: "kind:label · Analytics Overview number")
    }

    private static var notReported: String {
        String(localized: "Not reported yet", comment: "kind:label · Analytics Overview number without data")
    }

    private static func missing(_ kind: Kind, title: String, detail: String, tone: PageCardTone = .neutral, link: String?) -> AnalyticsKPI {
        AnalyticsKPI(kind: kind, title: title, value: "—", detail: detail, tone: tone, link: link, accessibilityText: opening("\(title): \(detail)", link))
    }

    /// The sentence, then where the link goes: "… Open Reviews".
    private static func opening(_ sentence: String, _ link: String?) -> String {
        guard let link else { return sentence }
        return sentence + ". " + String(localized: "Open \(link)", comment: "kind:accessibility-hint · where an Overview number leads")
    }

    private static func whole(_ amount: Decimal) -> Int {
        NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: nil).intValue
    }
}
