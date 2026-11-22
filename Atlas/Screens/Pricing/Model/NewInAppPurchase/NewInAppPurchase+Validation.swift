//
//  NewInAppPurchase+Validation.swift
//  Atlas
//

import Foundation

extension NewInAppPurchase {
    /// Everything App Store Connect would refuse, in the form's order, as
    /// Create Subscription words it. `takenProductIDs` are the app's
    /// products' and the new ones' in Review & Push.
    func problems(takenProductIDs: Set<String>) -> [NewSubscriptionProblem] {
        var problems = NewSubscription.textProblems(referenceName, field: .referenceName)
        problems += NewSubscription.productIDProblems(productID, taken: takenProductIDs)
        problems += NewSubscription.textProblems(displayName, field: .purchaseName)
        problems += NewSubscription.textProblems(description, field: .purchaseDescription)
        if let price {
            if !NewSubscription.isValidPrice(price) { problems.append(.invalidPrice) }
        } else {
            problems.append(.missing(.price))
        }
        problems += NewSubscription.textProblems(reviewNote, field: .reviewNote, isRequired: false)
        return problems
    }

    /// What App Review would reject in the display name or description,
    /// one reason per text, as `propose_in_app_purchase` refuses them.
    var guidelineReasons: [String] {
        let texts: [(argument: String, field: InAppTextField, text: String)] = [
            ("displayName", .purchaseName, displayName),
            ("description", .purchaseDescription, description),
        ]
        return texts.compactMap { argument, field, text in
            let issues = StoreTextGuidelineCheck.issues(in: text, for: field)
            return issues.isEmpty ? nil : "\(argument): \(issues.assistantReason)"
        }
    }
}
