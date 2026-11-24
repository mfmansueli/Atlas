//
//  SubscriptionStartingPrices.swift
//  Atlas
//

import Foundation

/// A subscription's first prices: a `POST /v1/subscriptionPrices` whose
/// price point is `{startingPrice:<territory>:<price>}`. Price points
/// belong to one subscription, so a new one's can only be read once it
/// exists; the push reads them then, sets the price in that territory and
/// Apple's equalized price everywhere else, like App Store Connect's
/// "Set Starting Price". A territory that has a price by then keeps it, so
/// a retry picks up where it stopped. A new subscription with the
/// recommended prices carries them as `overrides`: those territories get
/// their own point nearest that price instead of the equalized one.
///
/// The prices go in a few `PATCH /v1/subscriptions/{id}` with up to
/// `batchSize` inline price creates each (`SubscriptionUpdateRequest`'s
/// `included` `SubscriptionPriceInlineCreate`s, API 4.6.1). When App Store
/// Connect refuses that, the rest go one `POST /v1/subscriptionPrices` per
/// territory, `PushSchedule.concurrentRequests` at once.
struct SubscriptionStartingPrices: Hashable, Sendable {
    var subscriptionID: String
    /// The base territory, `USA`.
    var territoryID: String
    var customerPrice: Decimal
    /// Local prices by alpha-3 that replace the equalized ones.
    var overrides: [String: Decimal] = [:]

    static let placeholderPrefix = "{startingPrice:"

    /// `{startingPrice:USA:9.99}`, or with overrides
    /// `{startingPrice:USA:9.99:BRA=5.9,IND=69}`.
    static func placeholder(territoryID: String, price: Decimal, overrides: [String: Decimal] = [:]) -> String {
        let base = "\(placeholderPrefix)\(territoryID):\(NSDecimalNumber(decimal: price).stringValue)"
        guard !overrides.isEmpty else { return base + "}" }
        let list = overrides.keys.sorted().compactMap { key in overrides[key].map { "\(key)=\(NSDecimalNumber(decimal: $0).stringValue)" } }
        return base + ":" + list.joined(separator: ",") + "}"
    }

    /// The queued request: `subscriptionID` may be `{createdID:subscriptions}`.
    static func request(subscriptionID: String, territoryID: String, price: Decimal, overrides: [String: Decimal] = [:]) -> PushRequest {
        let body = SubscriptionPriceCreateRequest(
            subscriptionID: subscriptionID,
            territoryID: territoryID,
            pricePointID: placeholder(territoryID: territoryID, price: price, overrides: overrides),
            preserveCurrentPrice: false
        )
        return (try? PushRequest.json(.post, path, body)) ?? PushRequest(method: .post, path: path)
    }

    private static let path = "/v1/subscriptionPrices"

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let body = request.body,
              let document = try? JSONDecoder().decode(SubscriptionPriceCreateRequest.self, from: body)
        else { return nil }
        let point = document.data.relationships.subscriptionPricePoint.data.id
        guard point.hasPrefix(Self.placeholderPrefix), point.hasSuffix("}") else { return nil }
        let parts = point.dropFirst(Self.placeholderPrefix.count).dropLast().split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3, let price = Self.decimal(parts[1]) else { return nil }
        subscriptionID = document.data.relationships.subscription.data.id
        territoryID = parts[0]
        customerPrice = price
        if parts.count == 3 {
            for pair in parts[2].split(separator: ",") {
                let item = pair.split(separator: "=").map(String.init)
                guard item.count == 2, let value = Self.decimal(item[1]) else { continue }
                overrides[item[0]] = value
            }
        }
    }

    private static func decimal(_ text: String) -> Decimal? {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// One territory's price to set.
    struct TerritoryPrice: Hashable, Sendable {
        var territoryID: String
        var pricePointID: String
    }

    /// Inline price creates per `PATCH`.
    static let batchSize = 50

    /// What the per-territory `POST`s of every subscription of a push share
    /// (`PushSlots`).
    static let slotKey = "subscriptionPrices"

    // MARK: - Reads

    /// `GET` the subscription's price points in the base territory.
    var pricePointsPath: String {
        pricePointsPath(territoryID: territoryID)
    }

    /// `GET` the subscription's price points in one territory.
    func pricePointsPath(territoryID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/pricePoints?filter%5Bterritory%5D=\(territoryID)"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000"
    }

    /// The point closest to `price` (an exact one first); ties go higher.
    static func nearestPointID(to price: Decimal, in resources: [[String: Any]]) -> String? {
        let priced = resources.compactMap { resource -> (id: String, price: Decimal)? in
            guard let id = resource["id"] as? String, let value = Self.price(of: resource) else { return nil }
            return (id, value)
        }
        return priced.min { lhs, rhs in
            let left = (lhs.price - price).magnitude, right = (rhs.price - price).magnitude
            return left == right ? lhs.price > rhs.price : left < right
        }?.id
    }

    /// `GET` the points Apple equalizes with the base one, with their territory.
    func equalizationsPath(pricePointID: String) -> String {
        "/v1/subscriptionPricePoints/\(pricePointID)/equalizations?include=territory"
            + "&fields%5BsubscriptionPricePoints%5D=customerPrice,territory&fields%5Bterritories%5D=currency&limit=200"
    }

    /// `GET` the prices the subscription has, with their territory.
    var pricesPath: String {
        "/v1/subscriptions/\(subscriptionID)/prices?include=territory&fields%5BsubscriptionPrices%5D=territory"
            + "&fields%5Bterritories%5D=currency&limit=200"
    }

    /// The base territory's point at exactly `customerPrice`.
    func pricePointID(in resources: [[String: Any]]) -> String? {
        resources.first { Self.price(of: $0) == customerPrice }?["id"] as? String
    }

    /// The prices just below and above `customerPrice`, for the refusal.
    func nearest(in resources: [[String: Any]]) -> [Decimal] {
        let prices = resources.compactMap(Self.price(of:)).sorted()
        return [prices.last { $0 < customerPrice }, prices.first { $0 > customerPrice }].compactMap(\.self)
    }

    /// Each resource's territory: `relationships.territory.data.id`.
    static func territoryID(of resource: [String: Any]) -> String? {
        let relationships = resource["relationships"] as? [String: Any]
        let territory = relationships?["territory"] as? [String: Any]
        return (territory?["data"] as? [String: Any])?["id"] as? String
    }

    /// `POST` one territory's price, at once.
    func price(territoryID: String, pricePointID: String) -> PushRequest {
        let body = SubscriptionPriceCreateRequest(
            subscriptionID: subscriptionID,
            territoryID: territoryID,
            pricePointID: pricePointID,
            preserveCurrentPrice: false
        )
        return (try? PushRequest.json(.post, Self.path, body)) ?? PushRequest(method: .post, path: Self.path)
    }

    /// `PATCH` the subscription with `prices` as inline creates
    /// (`${price1}`, …), each starting at once for everyone.
    func batch(_ prices: [TerritoryPrice]) -> PushRequest {
        let localIDs = prices.indices.map { "${price\($0 + 1)}" }
        let included: [[String: Any]] = zip(localIDs, prices).map { localID, price in
            [
                "type": "subscriptionPrices",
                "id": localID,
                "attributes": ["preserveCurrentPrice": false],
                "relationships": [
                    "subscription": ["data": ["type": "subscriptions", "id": subscriptionID]],
                    "territory": ["data": ["type": "territories", "id": price.territoryID]],
                    "subscriptionPricePoint": ["data": ["type": "subscriptionPricePoints", "id": price.pricePointID]],
                ],
            ]
        }
        let body: [String: Any] = [
            "data": [
                "type": "subscriptions",
                "id": subscriptionID,
                "relationships": ["prices": ["data": localIDs.map { ["type": "subscriptionPrices", "id": $0] }]],
            ],
            "included": included,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return PushRequest(method: .patch, path: "/v1/subscriptions/\(subscriptionID)", body: data)
    }

    /// Apple said no to the batched write itself (409, 422 or another
    /// 4xx), so one `POST` per territory may still go: not a rate limit,
    /// a key problem, an outage or a timeout, which stop it as any request.
    static func isBatchRefusal(_ error: any Error) -> Bool {
        switch error as? AppStoreConnectError {
        case .rejected: true
        case let .server(statusCode, _, _): (400..<500).contains(statusCode)
        default: false
        }
    }

    // MARK: - Sending

    /// Reads the points and sets every price that's missing: in batched
    /// `PATCH`es when `batches`, and one territory at a time (a few at
    /// once, `slots`) for those left when App Store Connect refuses one or
    /// when not `batches`. `progress` gets (set, total) as they go through
    /// and `note` each response's rate limit. Returns the batched write's
    /// refusal, if there was one. Throws `SubscriptionStartingPriceError`
    /// when Apple has no point at that price. On the main actor, like the
    /// push that reports the progress.
    @MainActor
    @discardableResult
    func send(
        via transport: any PushTransport,
        slots: PushSlots,
        batches: Bool = true,
        progress: (Int, Int) -> Void,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> AppStoreConnectError? {
        let equalized = try await missingPrices(via: transport, note: note)
        let missing = try await applyingOverrides(to: equalized, via: transport, slots: slots, note: note)
        guard !missing.isEmpty else { return nil }
        var set = 0
        var left = missing[...]
        var refusal: AppStoreConnectError?
        while batches, !left.isEmpty {
            let chunk = Array(left.prefix(Self.batchSize))
            do {
                let response = try await transport.send(batch(chunk))
                note(response.rateLimit)
            } catch let error where Self.isBatchRefusal(error) {
                // Refused whole: nothing of it was set.
                refusal = error as? AppStoreConnectError
                break
            }
            left.removeFirst(chunk.count)
            set += chunk.count
            progress(set, missing.count)
        }
        try await slots.forEach(Array(left), key: Self.slotKey) { [self] price in
            try await transport.send(self.price(territoryID: price.territoryID, pricePointID: price.pricePointID))
        } finished: { _, response in
            note(response.rateLimit)
            set += 1
            progress(set, missing.count)
        }
        return refusal
    }

    /// The base territory's price and the equalized ones, for the
    /// territories that don't have a price yet.
    @MainActor
    func missingPrices(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [TerritoryPrice] {
        let points = try await Self.resources(at: pricePointsPath, via: transport, note: note)
        guard let baseID = pricePointID(in: points) else {
            throw SubscriptionStartingPriceError.noPricePoint(price: customerPrice, territoryID: territoryID, nearest: nearest(in: points))
        }
        let equalized = try await Self.resources(at: equalizationsPath(pricePointID: baseID), via: transport, note: note)
        let priced = try await Set(Self.resources(at: pricesPath, via: transport, note: note).compactMap(Self.territoryID(of:)))
        var wanted = [TerritoryPrice(territoryID: territoryID, pricePointID: baseID)]
        var seen: Set<String> = [territoryID]
        for point in equalized {
            guard let territory = Self.territoryID(of: point), let id = point["id"] as? String, !seen.contains(territory) else { continue }
            seen.insert(territory)
            wanted.append(TerritoryPrice(territoryID: territory, pricePointID: id))
        }
        return wanted.filter { !priced.contains($0.territoryID) }
    }

    /// The territories with a recommended price get their own point
    /// nearest it, read a few territories at once; the others, and any
    /// territory whose points don't come back, keep the equalized one.
    @MainActor
    func applyingOverrides(
        to prices: [TerritoryPrice],
        via transport: any PushTransport,
        slots: PushSlots,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [TerritoryPrice] {
        let wanted = prices.filter { $0.territoryID != territoryID && overrides[$0.territoryID] != nil }
        guard !wanted.isEmpty else { return prices }
        var chosen: [String: String] = [:]
        try await slots.forEach(wanted, key: Self.slotKey) { [self] price in
            try await transport.fetch(pricePointsPath(territoryID: price.territoryID))
        } finished: { price, response in
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            let points = object?["data"] as? [[String: Any]] ?? []
            if let target = overrides[price.territoryID], let id = Self.nearestPointID(to: target, in: points) {
                chosen[price.territoryID] = id
            }
        }
        return prices.map { price in
            chosen[price.territoryID].map { TerritoryPrice(territoryID: price.territoryID, pricePointID: $0) } ?? price
        }
    }

    /// Every page's `data`, following `links.next`.
    @MainActor
    private static func resources(
        at path: String,
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [[String: Any]] {
        var next: String? = path
        var result: [[String: Any]] = []
        while let page = next {
            let response = try await transport.fetch(page)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            result += object?["data"] as? [[String: Any]] ?? []
            next = (object?["links"] as? [String: Any])?["next"] as? String
        }
        return result
    }

    private static func price(of resource: [String: Any]) -> Decimal? {
        let attributes = resource["attributes"] as? [String: Any]
        return (attributes?["customerPrice"] as? String).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }
}
