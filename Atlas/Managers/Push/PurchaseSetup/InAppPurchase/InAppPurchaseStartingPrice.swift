//
//  InAppPurchaseStartingPrice.swift
//  Atlas
//

import Foundation

/// A new in-app purchase's price: `POST /v1/inAppPurchasePriceSchedules`
/// with the base territory and its one manual price. Price points belong to
/// one purchase, so a new one's can only be read once it exists: the queued
/// request's point is `{iapStartingPrice:<territory>:<price>}`, and the push
/// reads the purchase's points in that territory, picks the one at exactly
/// that price and sends the schedule. Apple sets the equalized price in
/// every other territory (`automaticPrices`). Sending it again replaces the
/// schedule with the same one, so a retry is safe.
struct InAppPurchaseStartingPrice: Hashable, Sendable {
    /// May be `{createdID:inAppPurchases}` until the push fills it in.
    var purchaseID: String
    /// The base territory, `USA`.
    var territoryID: String
    var customerPrice: Decimal

    static let path = "/v1/inAppPurchasePriceSchedules"
    static let placeholderPrefix = "{iapStartingPrice:"
    /// The inline price's local ID, as Apple's examples write it.
    static let inlinePriceID = "${base-price}"

    init(purchaseID: String, territoryID: String, customerPrice: Decimal) {
        self.purchaseID = purchaseID
        self.territoryID = territoryID
        self.customerPrice = customerPrice
    }

    /// The queued request; nil for any other.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let object = PushPagedRead.body(of: request),
              let data = object["data"] as? [String: Any],
              let purchaseID = PushPagedRead.relationshipID("inAppPurchase", of: data),
              let price = (object["included"] as? [[String: Any]])?.first,
              let point = PushPagedRead.relationshipID("inAppPurchasePricePoint", of: price),
              point.hasPrefix(Self.placeholderPrefix), point.hasSuffix("}")
        else { return nil }
        let parts = point.dropFirst(Self.placeholderPrefix.count).dropLast().split(separator: ":").map(String.init)
        guard parts.count == 2, let value = Decimal(string: parts[1], locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        self.purchaseID = purchaseID
        territoryID = parts[0]
        customerPrice = value
    }

    var placeholder: String {
        "\(Self.placeholderPrefix)\(territoryID):\(NSDecimalNumber(decimal: customerPrice).stringValue)}"
    }

    /// The queued request.
    var request: PushRequest {
        schedule(pricePointID: placeholder)
    }

    /// The schedule with this price point as the base territory's price.
    func schedule(pricePointID: String) -> PushRequest {
        PushPagedRead.request(.post, Self.path, [
            "data": [
                "type": "inAppPurchasePriceSchedules",
                "relationships": [
                    "inAppPurchase": ["data": ["type": "inAppPurchases", "id": purchaseID]],
                    "baseTerritory": ["data": ["type": "territories", "id": territoryID]],
                    "manualPrices": ["data": [["type": "inAppPurchasePrices", "id": Self.inlinePriceID]]],
                ],
            ],
            "included": [
                [
                    "type": "inAppPurchasePrices",
                    "id": Self.inlinePriceID,
                    "relationships": [
                        "inAppPurchaseV2": ["data": ["type": "inAppPurchases", "id": purchaseID]],
                        "inAppPurchasePricePoint": ["data": ["type": "inAppPurchasePricePoints", "id": pricePointID]],
                    ],
                ],
            ],
        ])
    }

    /// `GET` the purchase's price points in the base territory.
    var pricePointsPath: String {
        "/v2/inAppPurchases/\(purchaseID)/pricePoints?filter%5Bterritory%5D=\(territoryID)"
            + "&fields%5BinAppPurchasePricePoints%5D=customerPrice&limit=8000"
    }

    /// Reads the points and sends the schedule. Throws
    /// `InAppPurchasePriceError` when Apple has no point at that price.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws {
        let points = try await PushPagedRead.resources(at: pricePointsPath, via: transport, note: note).data
        guard let point = points.first(where: { PushPagedRead.customerPrice(of: $0) == customerPrice })?["id"] as? String else {
            let nearest = PushPagedRead.nearest(customerPrice, in: points)
            throw InAppPurchasePriceError.noPricePoint(price: customerPrice, territoryID: territoryID, nearest: nearest)
        }
        let response = try await transport.send(schedule(pricePointID: point))
        note(response.rateLimit)
    }
}
