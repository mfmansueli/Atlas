//
//  ReviewRiskProduct.swift
//  Atlas
//

import Foundation

/// One subscription or in-app purchase as the App Review checks read it:
/// Apple's state code, whether it's an auto-renewable subscription, and
/// whether App Review has its review screenshot.
struct ReviewRiskProduct: Hashable, Sendable {
    /// App Store Connect's resource ID.
    var id: String
    /// The product ID, e.g. `lumen.plus.annual`.
    var productID: String
    /// The reference name, e.g. "Annual".
    var name: String
    /// An auto-renewable subscription (in a subscription group).
    var isSubscription: Bool
    /// Apple's `state`, e.g. `READY_TO_SUBMIT`; nil when unknown.
    var state: String?
    /// Whether it has its App Review screenshot; nil when it wasn't read
    /// (only products still on their way to App Review are read).
    var hasReviewScreenshot: Bool?

    init(id: String, productID: String, name: String, isSubscription: Bool, state: String?, hasReviewScreenshot: Bool? = nil) {
        self.id = id
        self.productID = productID
        self.name = name
        self.isSubscription = isSubscription
        self.state = state
        self.hasReviewScreenshot = hasReviewScreenshot
    }

    static let missingMetadata = "MISSING_METADATA"
    static let readyToSubmit = "READY_TO_SUBMIT"
    static let rejected = "REJECTED"
    static let developerActionNeeded = "DEVELOPER_ACTION_NEEDED"

    /// Every state Apple's OpenAPI spec lists for `subscriptions` and
    /// `inAppPurchases` (v2).
    static let knownStates = [
        "MISSING_METADATA", "WAITING_FOR_UPLOAD", "PROCESSING_CONTENT", "READY_TO_SUBMIT", "WAITING_FOR_REVIEW", "IN_REVIEW",
        "DEVELOPER_ACTION_NEEDED", "PENDING_BINARY_APPROVAL", "APPROVED", "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE", "REJECTED",
    ]

    /// Approved once, so App Review has seen one like it (removed ones too).
    static let approvedStates: Set<String> = ["APPROVED", "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE"]

    /// Not sold any more: nothing to check.
    var isRemoved: Bool {
        state == "DEVELOPER_REMOVED_FROM_SALE" || state == "REMOVED_FROM_SALE"
    }

    var isApproved: Bool {
        state.map(Self.approvedStates.contains) ?? false
    }

    /// Still on its way to App Review: it needs its metadata and its
    /// review screenshot.
    var isBeforeReview: Bool {
        guard let state else { return false }
        return [Self.missingMetadata, Self.readyToSubmit, Self.rejected, Self.developerActionNeeded].contains(state)
    }

    /// Apple's code for Pricing's state words ("Ready to Submit"), for a
    /// product In-App Texts didn't read.
    static func code(forTitle title: String) -> String? {
        knownStates.first { LivePricingMapper.stateTitle($0) == title }
    }
}
