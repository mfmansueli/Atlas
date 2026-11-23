//
//  NewOfferCode+Validation.swift
//  Atlas
//

import Foundation

extension NewOfferCode {
    /// Everything App Store Connect would refuse, in the form's order.
    /// `existing` are the subscription's offer codes in App Store Connect,
    /// `takenNames` and `takenCustomCodes` those waiting in Review & Push.
    func problems(
        period: SubscriptionPeriod,
        subscriptionPrice: Decimal?,
        existing: [ExistingOfferCode],
        takenNames: Set<String> = [],
        takenCustomCodes: Set<String> = [],
        today: Date = .now
    ) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        if existing.count(where: \.isActive) + takenNames.count >= SubscriptionOfferRules.activePerSubscription {
            problems.append(.tooMany(.offerCode, limit: SubscriptionOfferRules.activePerSubscription))
        }
        problems += SubscriptionOfferRules.nameProblems(name, label: Self.nameLabel)
        if !trimmedName.isEmpty, existing.contains(where: { $0.name == trimmedName }) || takenNames.contains(trimmedName) {
            problems.append(.identifierTaken(Self.nameLabel, value: trimmedName))
        }
        if eligibilities.isEmpty { problems.append(.noCustomerEligibility) }
        problems += terms.problems(period: period, subscriptionPrice: subscriptionPrice)
        if let customCode {
            problems += customCode.problems(taken: ExistingOfferCode.customCodes(of: existing).union(takenCustomCodes), today: today)
        }
        if let oneTimeCodes { problems += oneTimeCodes.problems(today: today) }
        return problems
    }

    static var nameLabel: String { String(localized: "offer code name") }
}
