//
//  AppStoreConnectClient+ProductSubmissions.swift
//  Atlas
//

import Foundation

// Submitting a subscription or an in-app purchase for review, as Submit for
// Review does with the version. Apple's OpenAPI spec: `POST
// /v1/subscriptionSubmissions` with the `subscription` relationship and
// `POST /v1/inAppPurchaseSubmissions` with `inAppPurchaseV2`, no
// attributes; both answer 201 (409 or 422 when it can't be submitted).
extension AppStoreConnectClient {
    /// The submission's document for `product`.
    static func productSubmissionDocument(_ product: SubmissionProduct) -> [String: Any] {
        let (type, relationship, ownerType) = product.isSubscription
            ? ("subscriptionSubmissions", "subscription", "subscriptions")
            : ("inAppPurchaseSubmissions", "inAppPurchaseV2", "inAppPurchases")
        return [
            "data": [
                "type": type,
                "relationships": [relationship: ["data": ["type": ownerType, "id": product.id]]],
            ],
        ]
    }

    /// Where `product`'s submission is posted.
    static func productSubmissionPath(_ product: SubmissionProduct) -> String {
        product.isSubscription ? "/v1/subscriptionSubmissions" : "/v1/inAppPurchaseSubmissions"
    }

    /// Submits a subscription or in-app purchase for review.
    func submitForReview(_ product: SubmissionProduct) async throws {
        let body = try JSONSerialization.data(withJSONObject: Self.productSubmissionDocument(product))
        _ = try await send(PushRequest(method: .post, path: Self.productSubmissionPath(product), body: body))
    }

    /// The product's `state` now (`GET /v1/subscriptions/{id}` or
    /// `/v2/inAppPurchases/{id}`); nil when the answer has none.
    func reviewState(of product: SubmissionProduct) async throws -> String? {
        let path = product.isSubscription
            ? "/v1/subscriptions/\(product.id)?fields%5Bsubscriptions%5D=state"
            : "/v2/inAppPurchases/\(product.id)?fields%5BinAppPurchases%5D=state"
        let response = try await fetch(path)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        return ((object?["data"] as? [String: Any])?["attributes"] as? [String: Any])?["state"] as? String
    }
}
