//
//  NewWinBackOffer+Validation.swift
//  Atlas
//

import Foundation

extension NewWinBackOffer {
    /// Everything App Store Connect would refuse, in the form's order.
    /// `existing` are the subscription's win-back offers in App Store
    /// Connect, `takenOfferIDs` the offer IDs of others waiting in Review &
    /// Push.
    func problems(
        period: SubscriptionPeriod,
        subscriptionPrice: Decimal?,
        existing: [ExistingWinBackOffer],
        takenOfferIDs: Set<String> = [],
        today: Date = .now
    ) -> [SubscriptionOfferProblem] {
        var problems = SubscriptionOfferRules.nameProblems(referenceName, label: Self.nameLabel)
        let offerID = trimmedOfferID
        if !SubscriptionOfferRules.isValidIdentifier(offerID) {
            problems.append(.invalidIdentifier(Self.identifierLabel))
        } else if existing.contains(where: { $0.offerID == offerID }) || takenOfferIDs.contains(offerID) {
            problems.append(.identifierTaken(Self.identifierLabel, value: offerID))
        }
        problems += terms.problems(period: period, subscriptionPrice: subscriptionPrice)
        problems += settings.problems(today: today)
        return problems
    }

    static var nameLabel: String { String(localized: "reference name") }
    static var identifierLabel: String { String(localized: "offer ID") }
}
