//
//  ReviewShotProductStateReader.swift
//  Atlas
//

import Foundation

/// Reads a product's `state` with the push's transport (`GET
/// /v1/subscriptions/{id}` or `/v2/inAppPurchases/{id}`), and, while it's
/// Missing Metadata, whether it has a localization, its group has one and
/// it has a price: one-item pages of `subscriptionLocalizations`,
/// `subscriptionGroupLocalizations` and `prices` (an in-app purchase's
/// `inAppPurchaseLocalizations` and `iapPriceSchedule`). A read that fails
/// says nothing about that gap.
struct ReviewShotProductStateReader: ReviewShotProductStateReading {
    let transport: any PushTransport

    static func statePath(of product: PricingProduct) -> String {
        product.isInAppPurchase
            ? "/v2/inAppPurchases/\(product.id)?fields%5BinAppPurchases%5D=state"
            : "/v1/subscriptions/\(product.id)?fields%5Bsubscriptions%5D=state"
    }

    /// What's read for each gap; nil when it doesn't apply.
    static func path(of gap: ReviewShotProductState.Gap, product: PricingProduct, groupID: String?) -> String? {
        switch (gap, product.isInAppPurchase) {
        case (.localization, false): "/v1/subscriptions/\(product.id)/subscriptionLocalizations?limit=1"
        case (.localization, true): "/v2/inAppPurchases/\(product.id)/inAppPurchaseLocalizations?limit=1"
        case (.groupLocalization, false): groupID.map { "/v1/subscriptionGroups/\($0)/subscriptionGroupLocalizations?limit=1" }
        case (.groupLocalization, true): nil
        case (.prices, false): "/v1/subscriptions/\(product.id)/prices?limit=1"
        case (.prices, true): "/v2/inAppPurchases/\(product.id)/iapPriceSchedule"
        }
    }

    func state(of product: PricingProduct, groupID: String?) async throws -> ReviewShotProductState {
        let response = try await transport.fetch(Self.statePath(of: product))
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        let attributes = (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
        guard let code = attributes?["state"] as? String else { throw AppStoreConnectError.unexpectedPayload }
        var state = ReviewShotProductState(code: code)
        guard state.isMissingMetadata else { return state }
        for gap in ReviewShotProductState.Gap.allCases {
            guard let path = Self.path(of: gap, product: product, groupID: groupID) else { continue }
            if await isEmpty(path) == true { state.gaps.insert(gap) }
        }
        return state
    }

    /// Whether the page at `path` has nothing (a 404 counts); nil when it
    /// couldn't be read.
    private func isEmpty(_ path: String) async -> Bool? {
        do {
            let response = try await transport.fetch(path)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            if let list = object?["data"] as? [Any] { return list.isEmpty }
            return object?["data"] == nil || object?["data"] is NSNull
        } catch AppStoreConnectError.notFound {
            return true
        } catch {
            return nil
        }
    }
}
