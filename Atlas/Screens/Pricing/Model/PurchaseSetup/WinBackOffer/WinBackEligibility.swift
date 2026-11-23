//
//  WinBackEligibility.swift
//  Atlas
//

import Foundation

/// Who Apple shows a win-back offer to: people who paid for the
/// subscription at least `paidMonths`, stopped between
/// `sinceLastSubscribed` months ago, and (optionally) haven't had a
/// win-back offer for `waitMonths`.
struct WinBackEligibility: Hashable, Sendable {
    /// `customerEligibilityPaidSubscriptionDurationInMonths`.
    var paidMonths = 3
    /// `customerEligibilityTimeSinceLastSubscribedInMonths`.
    var sinceLastSubscribed = 1...12
    /// `customerEligibilityWaitBetweenOffersInMonths`.
    var waitMonths: Int?

    init(paidMonths: Int = 3, sinceLastSubscribed: ClosedRange<Int> = 1...12, waitMonths: Int? = nil) {
        self.paidMonths = paidMonths
        self.sinceLastSubscribed = sinceLastSubscribed
        self.waitMonths = waitMonths
    }

    /// From a win-back offer's attributes.
    init(attributes: [String: Any]) {
        paidMonths = attributes["customerEligibilityPaidSubscriptionDurationInMonths"] as? Int ?? 1
        let range = attributes["customerEligibilityTimeSinceLastSubscribedInMonths"] as? [String: Any]
        let minimum = range?["minimum"] as? Int ?? 1
        sinceLastSubscribed = minimum...max(minimum, range?["maximum"] as? Int ?? minimum)
        waitMonths = attributes["customerEligibilityWaitBetweenOffersInMonths"] as? Int
    }

    /// "Paid 3+ months · left 1–12 months ago · 6 months between offers".
    var summary: String {
        var parts = [
            String(localized: "Paid \(paidMonths)+ months"),
            String(localized: "left \(sinceLastSubscribed.lowerBound)–\(sinceLastSubscribed.upperBound) months ago"),
        ]
        if let waitMonths { parts.append(String(localized: "\(waitMonths) months between offers")) }
        return parts.joined(separator: " · ")
    }

    /// The attributes App Store Connect takes for it; no wait is `null`.
    var attributes: [String: Any] {
        [
            "customerEligibilityPaidSubscriptionDurationInMonths": paidMonths,
            "customerEligibilityTimeSinceLastSubscribedInMonths": [
                "minimum": sinceLastSubscribed.lowerBound, "maximum": sinceLastSubscribed.upperBound,
            ],
            "customerEligibilityWaitBetweenOffersInMonths": waitMonths.map { $0 as Any } ?? NSNull(),
        ]
    }

    var problems: [SubscriptionOfferProblem] {
        let months = SubscriptionOfferRules.eligibilityMonths
        var problems: [SubscriptionOfferProblem] = []
        if !months.contains(paidMonths) {
            problems.append(.invalidEligibilityMonths(String(localized: "How long they paid"), range: months))
        }
        if !months.contains(sinceLastSubscribed.lowerBound) || !months.contains(sinceLastSubscribed.upperBound) {
            problems.append(.invalidEligibilityMonths(String(localized: "The time since they last subscribed"), range: months))
        }
        if let waitMonths, !SubscriptionOfferRules.waitMonths.contains(waitMonths) {
            problems.append(.invalidEligibilityMonths(String(localized: "The wait between offers"), range: SubscriptionOfferRules.waitMonths))
        }
        return problems
    }
}
