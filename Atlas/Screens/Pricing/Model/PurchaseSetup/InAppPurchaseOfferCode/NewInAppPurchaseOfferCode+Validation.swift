//
//  NewInAppPurchaseOfferCode+Validation.swift
//  Atlas
//

import Foundation

extension NewInAppPurchaseOfferCode {
    /// Active offer codes per in-app purchase, as for a subscription.
    static let activePerPurchase = SubscriptionOfferRules.activePerSubscription

    static var nameLabel: String { String(localized: "offer code name") }

    /// Everything App Store Connect would refuse, in the form's order.
    /// `purchasePrice` is the purchase's US price, when known; `existing`
    /// are its offer codes in App Store Connect, `takenNames` and
    /// `takenCustomCodes` those waiting in Review & Push (custom codes are
    /// unique for the app, so they count every product's).
    func problems(
        purchasePrice: Decimal?,
        existing: [ExistingInAppPurchaseOfferCode],
        takenNames: Set<String> = [],
        takenCustomCodes: Set<String> = [],
        today: Date = .now
    ) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        if existing.count(where: \.isActive) + takenNames.count >= Self.activePerPurchase {
            problems.append(.tooManyInAppPurchaseOfferCodes(limit: Self.activePerPurchase))
        }
        problems += SubscriptionOfferRules.nameProblems(name, label: Self.nameLabel)
        if !trimmedName.isEmpty, existing.contains(where: { $0.name == trimmedName }) || takenNames.contains(trimmedName) {
            problems.append(.inAppPurchaseOfferCodeNameTaken(trimmedName))
        }
        if eligibilities.isEmpty { problems.append(.noSpenderEligibility) }
        problems += terms.problems(purchasePrice: purchasePrice)
        if let customCode {
            problems += customCode.problems(taken: ExistingInAppPurchaseOfferCode.customCodes(of: existing).union(takenCustomCodes), today: today)
        }
        if let oneTimeCodes { problems += oneTimeCodes.problems(today: today) }
        return problems
    }
}
