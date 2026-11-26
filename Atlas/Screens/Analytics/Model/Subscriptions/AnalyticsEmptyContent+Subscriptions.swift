//
//  AnalyticsEmptyContent+Subscriptions.swift
//  Atlas
//

import Foundation

extension AnalyticsEmptyContent {
    /// Subscriptions with nothing to show yet (board 92, "an-sub-none",
    /// "an-sub-trial", "an-sub-few"); nil when there is.
    static func subscriptions(_ soFar: SubscriptionsSoFar, appName: String) -> AnalyticsEmptyContent? {
        let availability = soFar.availability
        switch availability {
        case .noSubscriptionsSold:
            return AnalyticsEmptyContent(
                availability: availability,
                text: String(
                    localized: """
                    Apple starts the subscription reports the day after the first auto-renewable subscription is sold, free trials \
                    included. Until then there’s nothing to count.
                    """,
                    comment: "kind:description · Analytics → Subscriptions, nothing sold yet"
                ),
                facts: [
                    AnalyticsEmptyFact(
                        label: String(localized: "Reports start", comment: "kind:label · Analytics empty state fact"),
                        value: String(localized: "The day after the first sale", comment: "kind:label · Analytics empty state fact")
                    ),
                    AnalyticsEmptyFact(
                        label: String(localized: "Free trials", comment: "kind:label · Analytics empty state fact"),
                        value: String(localized: "Count as a sale", comment: "kind:label · Analytics empty state fact")
                    ),
                    pacificFact,
                ],
                note: String(
                    localized: "Atlas checks every morning. Trials, renewals and cancellations show here after the first sale.",
                    comment: "kind:hint · Analytics → Subscriptions, nothing sold yet"
                ),
                action: .openPricing
            )
        case let .noPaidSubscribers(trials):
            return AnalyticsEmptyContent(
                availability: availability,
                text: noPaidText(trials: trials),
                facts: [trialsFact(soFar.trials), paidFact(soFar.paid), trialEndFact(soFar) ?? firstSaleFact(soFar)].compactMap(\.self),
                note: String(
                    localized: "Apple leaves out rows with fewer than 5 people, so rates appear once there are more subscribers.",
                    comment: "kind:hint · Analytics → Subscriptions, trials only"
                ),
                action: .openPricing
            )
        case let .tooFewSubscribers(count):
            return AnalyticsEmptyContent(
                availability: availability,
                text: tooFewText(count: count, appName: appName),
                facts: [trialsFact(soFar.trials), paidFact(soFar.paid), trialToPaidFact(soFar)].compactMap(\.self)
            )
        case .available, .versionTooNew, .notEnoughPeople, .noCrashes:
            return nil
        }
    }

    /// "One free trial started, and nobody has paid yet. …"
    static func noPaidText(trials: Int) -> String {
        let started = trials == 1
            ? String(localized: "One free trial started, and nobody has paid yet.", comment: "kind:description · Analytics → Subscriptions, one trial")
            : String(
                localized: "\(AnalyticsText.count(trials)) free trials started, and nobody has paid yet.",
                comment: "kind:description · Analytics → Subscriptions, trials only"
            )
        let next = String(
            localized: "Renewals, cancellations and proceeds show here from the first payment.",
            comment: "kind:description · Analytics → Subscriptions, trials only"
        )
        return "\(started) \(next)"
    }

    /// "Parcel Pal has 4 subscribers so far. Apple leaves out rows with
    /// fewer than 5 people, …"
    static func tooFewText(count: Int, appName: String) -> String {
        let people = count == 1
            ? String(localized: "\(appName) has 1 subscriber so far.", comment: "kind:description · Analytics → Subscriptions, too few")
            : String(localized: "\(appName) has \(AnalyticsText.count(count)) subscribers so far.", comment: "kind:description · Analytics → Subscriptions, too few")
        let rule = String(
            localized: "Apple leaves out rows with fewer than 5 people, so renewal and cancel rates show once there are more. The counts below are complete.",
            comment: "kind:description · Analytics → Subscriptions, too few"
        )
        return "\(people) \(rule)"
    }

    private static func trialsFact(_ trials: Int) -> AnalyticsEmptyFact {
        AnalyticsEmptyFact(label: String(localized: "Trials", comment: "kind:label · Analytics empty state fact"), value: AnalyticsText.count(trials))
    }

    private static func paidFact(_ paid: Int) -> AnalyticsEmptyFact {
        AnalyticsEmptyFact(label: String(localized: "Paid", comment: "kind:label · Analytics empty state fact"), value: AnalyticsText.count(paid))
    }

    private static func firstSaleFact(_ soFar: SubscriptionsSoFar) -> AnalyticsEmptyFact? {
        soFar.firstSale.map { day in
            AnalyticsEmptyFact(label: String(localized: "First sale", comment: "kind:label · Analytics empty state fact"), value: AnalyticsText.day(day.date))
        }
    }

    /// "First trial ends" · "Nov 13", or once it ended (Pacific), when its
    /// payment would show.
    static func trialEndFact(_ soFar: SubscriptionsSoFar) -> AnalyticsEmptyFact? {
        guard let end = soFar.firstTrialEnds else { return nil }
        guard soFar.firstTrialHasEnded else {
            return AnalyticsEmptyFact(
                label: String(localized: "First trial ends", comment: "kind:label · Analytics empty state fact"),
                value: AnalyticsText.day(end.date)
            )
        }
        return AnalyticsEmptyFact(
            label: String(localized: "First trial ended", comment: "kind:label · Analytics empty state fact"),
            value: String(
                localized: "\(AnalyticsText.day(end.date)) · a payment shows a day later",
                comment: "kind:label · Analytics empty state fact, when a trial's payment shows"
            )
        )
    }

    /// "Trial → paid" · "1 of 4 · too few to tell".
    private static func trialToPaidFact(_ soFar: SubscriptionsSoFar) -> AnalyticsEmptyFact? {
        guard soFar.trials > 0 else { return nil }
        return AnalyticsEmptyFact(
            label: String(localized: "Trial → paid", comment: "kind:label · Analytics empty state fact"),
            value: String(
                localized: "\(AnalyticsText.count(soFar.paidFromTrials)) of \(AnalyticsText.count(soFar.trials)) · too few to tell",
                comment: "kind:label · Analytics empty state fact"
            )
        )
    }
}
