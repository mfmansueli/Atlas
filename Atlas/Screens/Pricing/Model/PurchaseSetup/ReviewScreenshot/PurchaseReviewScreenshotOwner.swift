//
//  PurchaseReviewScreenshotOwner.swift
//  Atlas
//

import Foundation

/// What an App Review screenshot belongs to: a subscription or an in-app
/// purchase. Each has one; without it the product stays in Missing
/// Metadata, App Review can't see it and StoreKit doesn't return it.
enum PurchaseReviewScreenshotOwner: String, Codable, Hashable, Sendable {
    case subscription = "subscriptions"
    case inAppPurchase = "inAppPurchases"

    /// The owner's resource type: `subscriptions` or `inAppPurchases`.
    var ownerType: String { rawValue }

    /// `subscriptionAppStoreReviewScreenshots` or
    /// `inAppPurchaseAppStoreReviewScreenshots`.
    var screenshotType: String {
        switch self {
        case .subscription: "subscriptionAppStoreReviewScreenshots"
        case .inAppPurchase: "inAppPurchaseAppStoreReviewScreenshots"
        }
    }

    /// The reservation's relationship to its owner.
    var relationship: String {
        switch self {
        case .subscription: "subscription"
        case .inAppPurchase: "inAppPurchaseV2"
        }
    }

    /// `POST` reserves one here; `PATCH`, `GET` and `DELETE` take `/{id}`.
    var collectionPath: String { "/v1/\(screenshotType)" }

    /// `GET` the owner's screenshot now, if it has one.
    func currentPath(ownerID: String) -> String {
        let fields = "fields%5B\(screenshotType)%5D=fileName,fileSize,sourceFileChecksum,assetDeliveryState"
        switch self {
        case .subscription: return "/v1/subscriptions/\(ownerID)/appStoreReviewScreenshot?\(fields)"
        case .inAppPurchase: return "/v2/inAppPurchases/\(ownerID)/appStoreReviewScreenshot?\(fields)"
        }
    }

    /// `GET` one screenshot's delivery state after the commit.
    func statusPath(id: String) -> String {
        "\(collectionPath)/\(id)?fields%5B\(screenshotType)%5D=assetDeliveryState"
    }
}
