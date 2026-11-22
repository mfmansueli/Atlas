//
//  PurchaseExtrasReader.swift
//  Atlas
//

import Foundation

/// Reads a product's introductory offers and App Review screenshot with
/// the push's transport (the API client): `GET
/// /v1/subscriptions/{id}/introductoryOffers` with their territories and
/// price points, and the product's `appStoreReviewScreenshot`. Pricing's
/// own services don't read either.
struct PurchaseExtrasReader: PurchaseExtrasReading {
    let transport: any PushTransport

    /// `GET` a subscription's introductory offers with their terms,
    /// territory and price.
    static func introductoryOffersPath(subscriptionID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/introductoryOffers?include=territory,subscriptionPricePoint"
            + "&fields%5BsubscriptionIntroductoryOffers%5D=duration,offerMode,numberOfPeriods,startDate,endDate,territory,subscriptionPricePoint"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice&fields%5Bterritories%5D=currency&limit=200"
    }

    func extras(for product: PricingProduct) async throws -> PurchaseExtras {
        var extras = PurchaseExtras()
        if !product.isInAppPurchase {
            let read = try await PushPagedRead.resources(at: Self.introductoryOffersPath(subscriptionID: product.id), via: transport) { _ in }
            extras.introductoryOffers = read.data.compactMap { ExistingIntroductoryOffer(resource: $0, included: read.included) }
        }
        let owner: PurchaseReviewScreenshotOwner = product.isInAppPurchase ? .inAppPurchase : .subscription
        do {
            let response = try await transport.fetch(owner.currentPath(ownerID: product.id))
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            extras.reviewScreenshot = PurchaseReviewScreenshotState(resource: object?["data"] as? [String: Any])
        } catch AppStoreConnectError.notFound {
            extras.reviewScreenshot = .missing
        }
        return extras
    }
}
