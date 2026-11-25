//
//  ProductRiskFixtures.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Facts for the subscription and in-app purchase checks, built by hand.
enum ProductRiskFixtures {
    static let terms = "Terms of Use: https://lumen.example.com/terms"
    static let germanTerms = "Nutzungsbedingungen: https://lumen.example.de/agb"
    static let noLink = "Lumen keeps a journal of your moods. Subscribe to Lumen Plus for unlimited entries."

    static func annual(state: String? = "APPROVED", screenshot: Bool? = nil) -> ReviewRiskProduct {
        ReviewRiskProduct(id: "s1", productID: "lumen.plus.annual", name: "Annual", isSubscription: true, state: state, hasReviewScreenshot: screenshot)
    }

    static func monthly(state: String? = "APPROVED", screenshot: Bool? = nil) -> ReviewRiskProduct {
        ReviewRiskProduct(id: "s2", productID: "lumen.plus.monthly", name: "Monthly", isSubscription: true, state: state, hasReviewScreenshot: screenshot)
    }

    static func lifetime(state: String? = "APPROVED", screenshot: Bool? = nil) -> ReviewRiskProduct {
        ReviewRiskProduct(id: "p1", productID: "lumen.lifetime", name: "Lifetime", isSubscription: false, state: state, hasReviewScreenshot: screenshot)
    }

    /// Lumen with `products`, its descriptions per locale (en-US
    /// primary), the license agreement and a privacy policy in en-US
    /// unless `privacy` is false.
    static func facts(
        _ products: [ReviewRiskProduct] = [annual()],
        descriptions: [String: String] = ["en-US": terms],
        eula: Bool? = false,
        privacy: Bool = true,
        preparedVersion: String? = nil
    ) -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: "6450000001", appName: "Lumen", bundleID: "com.example.lumen")
        let locales = ["en-US"] + descriptions.keys.filter { $0 != "en-US" }.sorted()
        facts.products = ReviewRiskProductFacts(
            products: products, hasCustomEULA: eula, descriptions: descriptions, locales: locales, primaryLocale: "en-US",
            preparedVersion: preparedVersion
        )
        facts.links = ReviewRiskLinkFacts(
            privacyPolicyURLs: privacy ? ["en-US": "https://lumen.example.com/privacy"] : [:], locales: locales, primaryLocale: "en-US"
        )
        return facts
    }

    static func risk(_ outcome: ReviewRiskOutcome, _ id: String) -> ReviewRisk? {
        guard case let .risks(risks) = outcome else { return nil }
        return risks.first { $0.id == id }
    }

    static func ids(_ outcome: ReviewRiskOutcome) -> [String] {
        guard case let .risks(risks) = outcome else { return [] }
        return risks.map(\.id)
    }
}
