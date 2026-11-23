//
//  NewPromotionalOffer+Validation.swift
//  Atlas
//

import Foundation

extension NewPromotionalOffer {
    /// Everything App Store Connect would refuse, in the form's order.
    /// `existing` are the subscription's promotional offers in App Store
    /// Connect, `takenIdentifiers` the identifiers of others waiting in
    /// Review & Push.
    func problems(
        period: SubscriptionPeriod,
        subscriptionPrice: Decimal?,
        existing: [ExistingPromotionalOffer],
        takenIdentifiers: Set<String> = []
    ) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        if existing.count + takenIdentifiers.count >= SubscriptionOfferRules.activePerSubscription {
            problems.append(.tooMany(.promotional, limit: SubscriptionOfferRules.activePerSubscription))
        }
        problems += SubscriptionOfferRules.nameProblems(name, label: Self.nameLabel)
        let identifier = trimmedIdentifier
        if !SubscriptionOfferRules.isValidIdentifier(identifier) {
            problems.append(.invalidIdentifier(Self.identifierLabel))
        } else if existing.contains(where: { $0.identifier == identifier }) || takenIdentifiers.contains(identifier) {
            problems.append(.identifierTaken(Self.identifierLabel, value: identifier))
        }
        problems += terms.problems(period: period, subscriptionPrice: subscriptionPrice)
        return problems
    }

    static var nameLabel: String { String(localized: "reference name") }
    static var identifierLabel: String { String(localized: "offer identifier") }
}
