//
//  ReviewRiskFactsLoader+Products.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// Most products whose review screenshot is read in one run.
    static let reviewScreenshotReads = 20

    /// The products from Pricing's catalog with Apple's state (In-App
    /// Texts has the codes; Pricing only words), the review screenshot of
    /// each still on its way to App Review, the license agreement, the
    /// descriptions as pushed and the version being prepared. Nil when the
    /// catalog couldn't be read.
    func productFacts(for app: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskProductFacts? {
        guard let catalog = shared.catalog else { return nil }
        var facts = Self.productFacts(catalog: catalog, inAppTexts: shared.inAppTexts, storePage: shared.storePage)
        var reads = 0
        for index in facts.products.indices where facts.products[index].isBeforeReview && reads < Self.reviewScreenshotReads {
            reads += 1
            facts.products[index].hasReviewScreenshot = await hasReviewScreenshot(facts.products[index])
        }
        facts.hasCustomEULA = await ReviewRiskEULAReader(transport: services.push).hasCustomEULA(appID: app.id)
        return facts
    }

    /// Everything but the reads: the products, their state codes, the
    /// descriptions and the version being prepared.
    static func productFacts(catalog: PricingCatalog, inAppTexts: InAppTextsContent?, storePage: StorePageContent?) -> ReviewRiskProductFacts {
        let states = inAppTexts?.productStates ?? [:]
        var facts = ReviewRiskProductFacts()
        facts.products = catalog.products.map { product in
            ReviewRiskProduct(
                id: product.id, productID: product.productID, name: product.name, isSubscription: !product.isInAppPurchase,
                state: states[product.productID] ?? ReviewRiskProduct.code(forTitle: product.reviewState)
            )
        }
        if let storePage {
            facts.primaryLocale = storePage.primaryLocale.code
            facts.locales = storePage.locales.map(\.code)
            for locale in storePage.locales {
                if let description = storePage.texts[locale]?[.description] { facts.descriptions[locale.code] = description }
            }
            facts.preparedVersion = storePage.editableVersion?.versionString
        }
        return facts
    }

    /// Whether App Store Connect has the product's review screenshot
    /// (`appStoreReviewScreenshot`); nil when it couldn't be read.
    private func hasReviewScreenshot(_ product: ReviewRiskProduct) async -> Bool? {
        let owner: PurchaseReviewScreenshotOwner = product.isSubscription ? .subscription : .inAppPurchase
        do {
            let response = try await services.push.fetch(owner.currentPath(ownerID: product.id))
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            switch PurchaseReviewScreenshotState(resource: object?["data"] as? [String: Any]) {
            case .missing, .failed: return false
            case .processing, .uploaded: return true
            }
        } catch AppStoreConnectError.notFound {
            return false
        } catch {
            return nil
        }
    }
}
