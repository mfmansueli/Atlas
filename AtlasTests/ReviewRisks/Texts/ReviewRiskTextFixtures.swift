//
//  ReviewRiskTextFixtures.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Store texts and facts built by hand for the text checks' tests.
enum ReviewRiskTextFixtures {
    static func listing(_ field: ListingField, _ text: String, locale: String = "en-US", isQueued: Bool = false) -> ReviewRiskText {
        ReviewRiskText(
            place: .storeListing,
            field: field,
            label: "\(field.title) · \(locale)",
            locale: locale,
            text: text,
            isQueued: isQueued,
            key: "storeListing.\(field.rawValue).\(locale)"
        )
    }

    static func text(
        _ place: ReviewRiskTextPlace, _ text: String, locale: String = "en-US", inAppField: InAppTextField? = nil, owner: String? = nil
    ) -> ReviewRiskText {
        ReviewRiskText(
            place: place,
            field: nil,
            label: "\(place.rawValue) · \(locale)",
            locale: locale,
            text: text,
            key: "\(place.rawValue).\(owner ?? "x").\(locale)",
            inAppField: inAppField,
            owner: owner
        )
    }

    static func facts(
        _ texts: [ReviewRiskText],
        allowance: StoreTextGuidelineAllowance = StoreTextGuidelineAllowance(),
        appName: String = "Lumen",
        siblings: [ReviewRiskSiblingApp]? = nil
    ) -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: "app1", appName: appName)
        facts.texts = ReviewRiskTextFacts(texts: texts, primaryLocale: "en-US", allowance: allowance)
        facts.siblings = siblings
        return facts
    }

    static func facts(version: ReviewRiskVersionFacts, appName: String = "Alba") -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: "app1", appName: appName)
        facts.version = version
        return facts
    }

    static func risks(_ outcome: ReviewRiskOutcome) -> [ReviewRisk] {
        if case let .risks(risks) = outcome { return risks }
        return []
    }

    static func isNotChecked(_ outcome: ReviewRiskOutcome) -> Bool {
        if case .notChecked = outcome { return true }
        return false
    }
}
