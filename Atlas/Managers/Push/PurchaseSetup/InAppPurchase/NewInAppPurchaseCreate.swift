//
//  NewInAppPurchaseCreate.swift
//  Atlas
//

import Foundation

/// A new in-app purchase's `POST /v2/inAppPurchases`. A push that stopped
/// after it sends it again; App Store Connect refuses the product ID it
/// already has, so the push looks the purchase up among the app's and
/// carries on with that one instead of failing at the first step forever.
struct NewInAppPurchaseCreate: Hashable, Sendable {
    var request: PushRequest
    var productID: String
    var appID: String

    static let path = "/v2/inAppPurchases"

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let object = PushPagedRead.body(of: request),
              let data = object["data"] as? [String: Any],
              let productID = (data["attributes"] as? [String: Any])?["productId"] as? String,
              let appID = PushPagedRead.relationshipID("app", of: data)
        else { return nil }
        self.request = request
        self.productID = productID
        self.appID = appID
    }

    /// `GET` the app's in-app purchases with that product ID.
    var lookupPath: String {
        let encoded = productID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? productID
        return "/v1/apps/\(appID)/inAppPurchasesV2?filter%5BproductId%5D=\(encoded)&fields%5BinAppPurchases%5D=productId&limit=200"
    }

    /// The purchase with exactly that product ID.
    func purchaseID(in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let purchases = object?["data"] as? [[String: Any]] ?? []
        return purchases.first { ($0["attributes"] as? [String: Any])?["productId"] as? String == productID }?["id"] as? String
    }

    /// Creates the purchase, or finds the one a push made before. Returns
    /// its ID; `note` gets each response's rate limit. Throws App Store
    /// Connect's refusal when the app doesn't have it.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        do {
            let response = try await transport.send(request)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw AppStoreConnectError.unexpectedPayload }
            return id
        } catch let refusal as AppStoreConnectError {
            guard NewSubscriptionCreate.mayBeTaken(refusal) else { throw refusal }
            let found = try await transport.fetch(lookupPath)
            note(found.rateLimit)
            guard let id = purchaseID(in: found.data) else { throw refusal }
            return id
        }
    }
}
