//
//  PriceTestChanges.swift
//  Atlas
//

import Foundation

/// A price test in Review & Push (board 76): one item and one push for the
/// test price now and the old price back on day 28, two
/// `POST /v1/subscriptionPrices` per country. Ending a test is another
/// item: the old prices now, and for End Test and Set the new price in
/// that country, now and again on day 28 so the scheduled return doesn't
/// undo it.
enum PriceTestChanges {
    enum Kind: String, Sendable {
        case start
        case end
    }

    static let prefix = "pricetest."

    static func changeID(_ kind: Kind, testID: PriceTest.ID) -> PendingChange.ID {
        "\(prefix)\(kind.rawValue).\(testID)"
    }

    /// "pricetest.start.<id>" → start, id.
    static func reading(_ changeID: PendingChange.ID) -> (kind: Kind, testID: PriceTest.ID)? {
        guard changeID.hasPrefix(prefix) else { return nil }
        let rest = changeID.dropFirst(prefix.count)
        guard let dot = rest.firstIndex(of: "."), let kind = Kind(rawValue: String(rest[..<dot])) else { return nil }
        let id = String(rest[rest.index(after: dot)...])
        return id.isEmpty ? nil : (kind, id)
    }

    static func owns(_ change: PendingChange) -> Bool {
        reading(change.id) != nil
    }

    // MARK: - Start

    /// The test price now and the old price on day 28, in every country.
    /// A raise keeps existing subscribers on their price on the way in; a
    /// decrease lets those who renew pay it, and keeps it afterward when
    /// the person chose so.
    static func start(_ test: PriceTest, appID: StoreApp.ID, source: ChangeSource, at date: Date = .now) -> PendingChange {
        var requests: [PushRequest] = []
        var missing = 0
        for country in test.countries {
            guard let testID = country.testPricePointID, let oldID = country.oldPricePointID else {
                missing += 1
                continue
            }
            let into = SubscriptionPriceCreateRequest(
                subscriptionID: test.productID, territoryID: country.territoryID, pricePointID: testID, preserveCurrentPrice: country.isRaise
            )
            let back = SubscriptionPriceCreateRequest(
                subscriptionID: test.productID, territoryID: country.territoryID, pricePointID: oldID,
                preserveCurrentPrice: country.isRaise ? false : test.keepsTestPrice, startDate: PriceTestReturnDay.token
            )
            requests += [into, back].compactMap { try? PushRequest.json(.post, path, $0) }
        }
        var change = PendingChange(
            id: changeID(.start, testID: test.id),
            appID: appID,
            section: .subscriptionPricing,
            group: group(test),
            groupID: test.productID,
            groupNote: String(localized: "The test price now, the old prices on day 28", comment: "kind:label"),
            title: test.title,
            oldValue: String(localized: "Today’s prices", comment: "kind:label"),
            newValue: test.step.title,
            deltaPercent: percent(test.step),
            source: source,
            blockedReason: missing > 0 ? missingPoints(missing) : nil,
            requests: requests,
            restoreRequests: oldPrices(test, preserving: true),
            createdAt: date
        )
        change.creation = PendingCreation(
            id: "\(prefix)\(test.id)",
            title: rowTitle(test),
            detail: startLine(test),
            source: source,
            fields: test.countries.map { field($0, new: $0.testPrice) }
        )
        return change
    }

    /// "14 countries 20% lower for 28 days from when you push, then the
    /// old prices. Both go in this push."
    static func startLine(_ test: PriceTest) -> String {
        let count = test.countries.count
        return String(
            localized: "\(count) countries \(test.step.phrase) for 28 days from when you push, then the old prices. Both go in this push.",
            comment: "kind:sheet-body"
        )
    }

    /// "Pricing · Lumen Plus Annual · Europe price test".
    static func rowTitle(_ test: PriceTest) -> String {
        String(localized: "Pricing · \(test.productName) · \(test.title)", comment: "kind:title")
    }

    // MARK: - End

    /// End Test Early: the old prices now, people who paid the test price
    /// keeping it. End Test and Set: the same in the other countries, and
    /// the new price in that one, now and on day 28.
    static func end(
        _ test: PriceTest,
        ending: PriceTestEnding,
        pricePointID: String?,
        appID: StoreApp.ID,
        source: ChangeSource = .you,
        at date: Date = .now
    ) -> PendingChange {
        let others = test.countries.filter { $0.territoryID != ending.territoryID }
        var remaining = test
        remaining.countries = others
        var requests = oldPrices(remaining, preserving: true)
        var blocked: String?
        if let territoryID = ending.territoryID, ending.price != nil {
            if let pricePointID {
                let now = SubscriptionPriceCreateRequest(subscriptionID: test.productID, territoryID: territoryID, pricePointID: pricePointID)
                let later = SubscriptionPriceCreateRequest(
                    subscriptionID: test.productID, territoryID: territoryID, pricePointID: pricePointID, startDate: test.returnDay
                )
                requests += [now, later].compactMap { try? PushRequest.json(.post, path, $0) }
            } else {
                blocked = missingPoints(1)
            }
        }
        let missing = others.count { $0.oldPricePointID == nil }
        if missing > 0 { blocked = missingPoints(missing) }
        var change = PendingChange(
            id: changeID(.end, testID: test.id),
            appID: appID,
            section: .subscriptionPricing,
            group: group(test),
            groupID: test.productID,
            groupNote: String(localized: "Ends the test: no result", comment: "kind:label"),
            title: String(localized: "End the \(test.title)", comment: "kind:title"),
            oldValue: test.step.title,
            newValue: String(localized: "Old prices", comment: "kind:label"),
            source: source,
            blockedReason: blocked,
            requests: requests,
            createdAt: date
        )
        var fields = others.map { field($0, new: $0.oldPrice, old: $0.testPrice) }
        if let territoryID = ending.territoryID, let price = ending.price, let country = test.country(territoryID) {
            fields.insert(field(country, new: price, old: country.testPrice), at: 0)
        }
        change.creation = PendingCreation(
            id: "\(prefix)end.\(test.id)",
            title: String(localized: "Pricing · \(test.productName) · End the \(test.title)", comment: "kind:title"),
            detail: String(localized: "The old prices come back in \(others.count) countries when you push. No result.", comment: "kind:sheet-body"),
            source: source,
            fields: fields
        )
        return change
    }

    // MARK: - Private

    private static let path = "/v1/subscriptionPrices"

    private static func group(_ test: PriceTest) -> String {
        String(localized: "Subscription Pricing · \(test.productName)", comment: "kind:label")
    }

    private static func percent(_ step: PriceTestStep) -> Int? {
        if case let .percent(value) = step { return value }
        return nil
    }

    private static func oldPrices(_ test: PriceTest, preserving: Bool) -> [PushRequest] {
        test.countries.compactMap { country in
            guard let id = country.oldPricePointID else { return nil }
            let body = SubscriptionPriceCreateRequest(
                subscriptionID: test.productID, territoryID: country.territoryID, pricePointID: id, preserveCurrentPrice: preserving
            )
            return try? PushRequest.json(.post, path, body)
        }
    }

    private static func field(_ country: PriceTestCountry, new: Decimal, old: Decimal? = nil) -> PendingChangePart {
        PendingChangePart(
            id: country.territoryID + ".priceTest",
            title: TerritoryCatalog.standard.territory(alpha3: country.territoryID)?.name ?? country.territoryID,
            oldValue: country.currency.format(old ?? country.oldPrice),
            newValue: country.currency.format(new),
            source: .you
        )
    }

    private static func missingPoints(_ count: Int) -> String {
        count == 1
            ? String(localized: "Apple’s price point for 1 country isn’t loaded. Refresh, then set it up again.", comment: "kind:error")
            : String(localized: "Apple’s price points for \(count) countries aren’t loaded. Refresh, then set it up again.", comment: "kind:error")
    }
}
