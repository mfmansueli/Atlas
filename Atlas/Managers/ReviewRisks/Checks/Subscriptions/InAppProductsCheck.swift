//
//  InAppProductsCheck.swift
//  Atlas
//

import Foundation

/// 2.1(b): subscriptions and in-app purchases App Review can't see or
/// take: Missing Metadata, without their review screenshot, sent back by
/// App Review (Rejected, Developer Action Needed), or Ready to Submit and
/// not submitted while a version is being prepared (the first
/// subscription or in-app purchase only reaches App Review with one).
/// Each risk groups the products it's about and names them.
struct InAppProductsCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.inAppProducts

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let products = facts.products else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the app’s in-app purchases.", comment: "kind:error")))
        }
        let sold = products.products.filter { !$0.isRemoved }
        var risks: [ReviewRisk] = []
        let missingMetadata = sold.filter { $0.state == ReviewRiskProduct.missingMetadata }
        if !missingMetadata.isEmpty { risks.append(missingMetadataRisk(missingMetadata)) }
        let noScreenshot = sold.filter { $0.isBeforeReview && $0.hasReviewScreenshot == false }
        if !noScreenshot.isEmpty { risks.append(screenshotRisk(noScreenshot)) }
        let sentBack = sold.filter { $0.state == ReviewRiskProduct.rejected || $0.state == ReviewRiskProduct.developerActionNeeded }
        if !sentBack.isEmpty { risks.append(sentBackRisk(sentBack)) }
        if let version = products.preparedVersion {
            let ready = sold.filter { $0.state == ReviewRiskProduct.readyToSubmit }
            if !ready.isEmpty { risks.append(notSubmittedRisk(ready, version: version, firsts: ready.filter(products.isFirst))) }
        }
        return .risks(risks)
    }

    // MARK: - Evidence

    /// "Annual · Subscription", with its product ID and state.
    static func evidence(_ product: ReviewRiskProduct) -> ReviewRiskEvidence {
        let kind = product.isSubscription
            ? String(localized: "Subscription", comment: "kind:label · a kind of product")
            : String(localized: "In-App Purchase", comment: "kind:label · a kind of product")
        let state = product.state.map { LivePricingMapper.stateTitle($0) }
        return ReviewRiskEvidence(place: "\(product.name) · \(kind)", excerpt: [product.productID, state].compactMap(\.self).joined(separator: " · "))
    }

    /// "“Annual”".
    private static func quoted(_ product: ReviewRiskProduct) -> String {
        "“\(product.name)”"
    }

    private static func productIDs(_ products: [ReviewRiskProduct]) -> String {
        products.map(\.productID).joined(separator: ",")
    }

    // MARK: - Risks

    private func missingMetadataRisk(_ products: [ReviewRiskProduct]) -> ReviewRisk {
        let title = products.count == 1
            ? String(localized: "\(Self.quoted(products[0])) is missing metadata", comment: "kind:title · an App Review risk")
            : String(localized: "\(products.count) products are missing metadata", comment: "kind:title · an App Review risk")
        let why = products.count == 1
            ? String(
                localized: "App Store Connect won’t send it to App Review until its texts, prices and screenshot are in.",
                comment: "kind:description · why an App Review risk matters"
            )
            : String(
                localized: "App Store Connect won’t send \(products.count) products to App Review until their metadata is in.",
                comment: "kind:description · why an App Review risk matters"
            )
        return ReviewRisk(
            check: id, subject: "missingMetadata", level: .blocksReview, title: title, why: why, evidence: products.map(Self.evidence), howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "In Pricing, add what each one lacks: its texts, prices or review screenshot.",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                arguments: ["productIds": Self.productIDs(products)]
            )
        )
    }

    private func screenshotRisk(_ products: [ReviewRiskProduct]) -> ReviewRisk {
        let title = products.count == 1
            ? String(localized: "\(Self.quoted(products[0])) has no review screenshot", comment: "kind:title · an App Review risk")
            : String(localized: "\(products.count) products have no review screenshot", comment: "kind:title · an App Review risk")
        let why = products.count == 1
            ? String(
                localized: "App Review needs a screenshot of the purchase in the app; 1 product has none.",
                comment: "kind:description · why an App Review risk matters"
            )
            : String(
                localized: "App Review needs a screenshot of each purchase in the app; \(products.count) products have none.",
                comment: "kind:description · why an App Review risk matters"
            )
        var arguments = ["productIds": Self.productIDs(products)]
        arguments["productId"] = products[0].productID
        return ReviewRisk(
            check: id, subject: "reviewScreenshot", level: .blocksReview, title: title, why: why, evidence: products.map(Self.evidence), howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add a screenshot of each one’s purchase screen in Pricing → Review Screenshot.",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                tool: "propose_purchase_review_screenshot",
                arguments: arguments
            )
        )
    }

    private func sentBackRisk(_ products: [ReviewRiskProduct]) -> ReviewRisk {
        let title = products.count == 1
            ? String(localized: "App Review sent back \(Self.quoted(products[0]))", comment: "kind:title · an App Review risk")
            : String(localized: "App Review sent back \(products.count) products", comment: "kind:title · an App Review risk")
        let why = products.count == 1
            ? String(
                localized: "1 product waits for your fix. App Review’s message is in App Store Connect.",
                comment: "kind:description · why an App Review risk matters"
            )
            : String(
                localized: "\(products.count) products wait for your fix. App Review’s message is in App Store Connect.",
                comment: "kind:description · why an App Review risk matters"
            )
        return ReviewRisk(
            check: id, subject: "sentBack", level: .blocksReview, title: title, why: why, evidence: products.map(Self.evidence), howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Read App Review’s message in App Store Connect, fix the product, then submit it again.",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                arguments: ["productIds": Self.productIDs(products)]
            )
        )
    }

    /// Ready to Submit while a version is prepared: the first subscription
    /// (or in-app purchase) can only go with it, so leaving it out stops
    /// App Review from seeing it; later ones can go on their own.
    private func notSubmittedRisk(_ products: [ReviewRiskProduct], version: String, firsts: [ReviewRiskProduct]) -> ReviewRisk {
        let title = products.count == 1
            ? String(localized: "Submit \(Self.quoted(products[0])) with \(version)", comment: "kind:title · an App Review risk")
            : String(localized: "Submit \(products.count) products with \(version)", comment: "kind:title · an App Review risk")
        let why = firsts.isEmpty
            ? String(
                localized: "\(products.count) ready to submit; App Review won’t see them until they’re submitted.",
                comment: "kind:description · why an App Review risk matters"
            )
            : String(
                localized: "A first purchase only reaches App Review with a version; \(products.count) wait to go.",
                comment: "kind:description · why an App Review risk matters"
            )
        return ReviewRisk(
            check: id, subject: "notSubmitted", level: firsts.isEmpty ? .likely : .blocksReview, title: title, why: why,
            evidence: products.map(Self.evidence), howSure: .fairlySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Leave them ticked in Submit for Review, so they go to App Review with \(version).",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                arguments: ["productIds": Self.productIDs(products)]
            )
        )
    }
}
