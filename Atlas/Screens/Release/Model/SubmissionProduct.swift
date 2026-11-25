//
//  SubmissionProduct.swift
//  Atlas
//

import Foundation

/// A subscription or in-app purchase that can go to App Review with the
/// version: Ready to Submit in App Store Connect. Submit sends each one
/// ticked (`POST /v1/subscriptionSubmissions` or
/// `/v1/inAppPurchaseSubmissions`) before it sends the review
/// submission, so the first one goes with the version as Apple requires.
struct SubmissionProduct: Identifiable, Hashable, Codable, Sendable {
    /// App Store Connect's `subscriptions` or `inAppPurchases` ID.
    var id: String
    /// "lumen.plus.annual".
    var productID: String
    /// The reference name, "Annual".
    var name: String
    /// An auto-renewable subscription; else an in-app purchase.
    var isSubscription: Bool
    /// The app's first of its kind: App Review only takes it with a
    /// version, so leaving it out means it waits for the next one.
    var isFirst = false

    /// A product as App Store Connect lists it, before Submit knows
    /// whether it can go.
    struct Candidate: Hashable, Sendable {
        var id: String
        var productID: String
        var name: String
        var state: String?
    }

    static let readyToSubmit = "READY_TO_SUBMIT"
    /// Approved once (removed ones too): App Review has seen one like it.
    static let approvedStates: Set<String> = ["APPROVED", "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE"]

    /// "Subscription “Annual”", for the Submit sheet's row.
    var title: String {
        isSubscription
            ? String(localized: "Subscription “\(name)”", comment: "kind:label · a product that goes with the version")
            : String(localized: "In-App Purchase “\(name)”", comment: "kind:label · a product that goes with the version")
    }

    /// The row's second line: "lumen.plus.annual · Ready to Submit · first
    /// subscription, goes with the version".
    var detail: String {
        var parts = [productID, LivePricingMapper.stateTitle(Self.readyToSubmit)]
        if isFirst {
            parts.append(isSubscription
                ? String(
                    localized: "Your first subscription: it only goes with a version",
                    comment: "kind:description · a product that goes with the version"
                )
                : String(
                    localized: "Your first in-app purchase: it only goes with a version",
                    comment: "kind:description · a product that goes with the version"
                ))
        }
        return parts.joined(separator: " · ")
    }

    /// The products Ready to Submit among the app's subscriptions and
    /// in-app purchases (as `pricedSubscriptionGroups` and
    /// `pricedInAppPurchases` read them), each marked first when none of
    /// its kind was approved before.
    static func ready(
        subscriptions: [Candidate],
        inAppPurchases: [Candidate]
    ) -> [SubmissionProduct] {
        let firstSubscription = !subscriptions.contains { $0.state.map(approvedStates.contains) ?? false }
        let firstPurchase = !inAppPurchases.contains { $0.state.map(approvedStates.contains) ?? false }
        let ready = subscriptions.filter { $0.state == readyToSubmit }.map {
            SubmissionProduct(id: $0.id, productID: $0.productID, name: $0.name, isSubscription: true, isFirst: firstSubscription)
        }
        return ready + inAppPurchases.filter { $0.state == readyToSubmit }.map {
            SubmissionProduct(id: $0.id, productID: $0.productID, name: $0.name, isSubscription: false, isFirst: firstPurchase)
        }
    }
}
