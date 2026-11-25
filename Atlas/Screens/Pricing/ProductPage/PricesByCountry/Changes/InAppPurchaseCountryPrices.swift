//
//  InAppPurchaseCountryPrices.swift
//  Atlas
//

import Foundation

/// An in-app purchase's prices by country as one Review & Push change.
/// App Store Connect keeps them in a price schedule: manual prices (the
/// base territory's and any set by hand) and automatic ones, which follow
/// the base price with exchange rates and tax. A price set here becomes a
/// manual price; "back to automatic" drops the territory's manual price.
/// Both are one `POST /v1/inAppPurchasePriceSchedules` with the base
/// territory and every manual price that stays, which replaces the
/// schedule (OpenAPI 4.6.1: `InAppPurchasePriceScheduleCreateRequest`,
/// `InAppPurchasePriceInlineCreate`). Restoring sends today's schedule
/// back.
struct InAppPurchaseCountryPrices {
    static let idPrefix = "iapPrice."
    static let path = "/v1/inAppPurchasePriceSchedules"

    let appID: StoreApp.ID
    let product: PricingProduct
    let sheet: ProductPriceSheet
    var territories = TerritoryCatalog.standard

    /// `iapPrice.<purchaseID>`: every country of one purchase in one change.
    static func changeID(productID: String) -> PendingChange.ID {
        "\(idPrefix)\(productID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The edits a queued change holds, by territory (alpha-3).
    static func edits(of change: PendingChange, territories: TerritoryCatalog = .standard) -> [String: CountryPriceEdit] {
        var edits: [String: CountryPriceEdit] = [:]
        for field in change.creation?.fields ?? [] {
            guard let reading = PricesByCountryChanges.reading(field) else { continue }
            if reading.isAutomatic {
                edits[reading.territoryID] = .automatic
            } else if let territory = territories.territory(alpha3: reading.territoryID),
                      let price = CurrencyFormat.forCurrency(territory.currencyCode).parse(field.newValue)
            {
                edits[reading.territoryID] = .price(price)
            }
        }
        return edits
    }

    /// A queued change's prices by territory, as Prices by Country and
    /// get_prices show them: Apple's automatic price at today's equalized one.
    static func queuedPrices(of change: PendingChange, sheet: ProductPriceSheet) -> [String: QueuedCountryPrice] {
        var result: [String: QueuedCountryPrice] = [:]
        for (territoryID, edit) in edits(of: change) {
            guard let price = sheet.prices[territoryID] else { continue }
            switch edit {
            case .automatic:
                result[territoryID] = QueuedCountryPrice(price: price.equalized.customerPrice, isAutomatic: true, source: change.source)
            case let .price(value):
                result[territoryID] = QueuedCountryPrice(price: value, isAutomatic: false, source: change.source)
            }
        }
        return result
    }

    /// Whether an edit asks for what the territory has today, so it needn't wait.
    func isToday(_ edit: CountryPriceEdit, territoryID: String) -> Bool {
        let isManual = manualTerritoryIDs.contains(territoryID)
        switch edit {
        case .automatic:
            return !isManual
        case let .price(price):
            guard isManual, let current = sheet.prices[territoryID]?.current else { return false }
            return !PricingRow.differs(price, current.customerPrice)
        }
    }

    /// Territories with a manual price today: what the sheet read, else
    /// those set apart from the equalized price, and always the base.
    var manualTerritoryIDs: Set<String> {
        let read = sheet.manualTerritoryIDs ?? Set(sheet.prices.values.filter(\.isCustom).map(\.territoryID))
        return read.union([sheet.baseTerritoryID])
    }

    /// The change for these edits (by territory), or nil when there are none.
    /// `ladder` gives a territory's price points, where a chosen price's
    /// point comes from.
    func change(
        edits: [String: CountryPriceEdit],
        ladder: (String) -> PricePointLadder?,
        source: ChangeSource,
        at date: Date = .now
    ) -> PendingChange? {
        guard !edits.isEmpty else { return nil }
        var manual: [String: PricePoint?] = [:]
        for territoryID in manualTerritoryIDs {
            manual[territoryID] = sheet.prices[territoryID]?.current
        }
        var fields: [PendingChangePart] = []
        for (territoryID, edit) in edits {
            guard let territory = territories.territory(alpha3: territoryID), let price = sheet.prices[territoryID] else { continue }
            switch edit {
            case .automatic:
                guard territoryID != sheet.baseTerritoryID else { continue }
                manual[territoryID] = nil
                fields.append(PricesByCountryChanges.field(
                    territory: territory, old: price.current.customerPrice, new: price.equalized.customerPrice, isAutomatic: true, source: source
                ))
            case let .price(value):
                manual[territoryID] = .some(ladder(territoryID)?.point(at: value))
                fields.append(PricesByCountryChanges.field(
                    territory: territory, old: price.current.customerPrice, new: value, isAutomatic: false, source: source
                ))
            }
        }
        guard !fields.isEmpty else { return nil }
        fields.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let pointIDs = manual.mapValues { $0?.appStoreConnectID }
        let isComplete = pointIDs.values.allSatisfy { $0 != nil }
        let requests = isComplete ? [request(pointIDs.compactMapValues(\.self))] : []
        let summary = PricesByCountrySummary.text(fields.compactMap(PricesByCountryChanges.summaryItem))
        var change = PendingChange(
            id: Self.changeID(productID: product.id),
            appID: appID,
            section: .subscriptionPricing,
            group: String(localized: "In-App Purchase Pricing · \(product.name)", comment: "kind:title"),
            title: product.name,
            oldValue: "",
            newValue: summary,
            source: source,
            blockedReason: isComplete
                ? nil
                : String(localized: "Apple’s price point for this price isn’t loaded. Refresh, then set it again.", comment: "kind:error"),
            requests: requests,
            restoreRequests: restoreRequests(),
            createdAt: date
        )
        change.creation = PendingCreation(
            id: PricesByCountryChanges.creationID(productID: product.id),
            title: PricesByCountryChanges.rowTitle(product),
            detail: detail(summary: summary),
            source: source,
            fields: fields
        )
        return change
    }

    /// The schedule: the base territory and each manual price, by point ID.
    func request(_ pointIDs: [String: String]) -> PushRequest {
        let territoryIDs = pointIDs.keys.sorted()
        let localID = { (territoryID: String) in "${price-\(territoryID)}" }
        return PushPagedRead.request(.post, Self.path, [
            "data": [
                "type": "inAppPurchasePriceSchedules",
                "relationships": [
                    "inAppPurchase": ["data": ["type": "inAppPurchases", "id": product.id]],
                    "baseTerritory": ["data": ["type": "territories", "id": sheet.baseTerritoryID]],
                    "manualPrices": ["data": territoryIDs.map { ["type": "inAppPurchasePrices", "id": localID($0)] }],
                ],
            ],
            "included": territoryIDs.map { territoryID in
                [
                    "type": "inAppPurchasePrices",
                    "id": localID(territoryID),
                    "relationships": [
                        "inAppPurchaseV2": ["data": ["type": "inAppPurchases", "id": product.id]],
                        "inAppPurchasePricePoint": ["data": ["type": "inAppPurchasePricePoints", "id": pointIDs[territoryID] ?? ""]],
                    ],
                ] as [String: Any]
            },
        ])
    }

    /// Today's schedule back, when every manual price's point is known.
    private func restoreRequests() -> [PushRequest] {
        var pointIDs: [String: String] = [:]
        for territoryID in manualTerritoryIDs {
            guard let id = sheet.prices[territoryID]?.current.appStoreConnectID else { return [] }
            pointIDs[territoryID] = id
        }
        return [request(pointIDs)]
    }

    private func detail(summary: String) -> String {
        guard sheet.laterManualPriceCount > 0 else { return summary }
        let count = sheet.laterManualPriceCount
        let replaces = count == 1
            ? String(localized: "It replaces 1 price change scheduled in App Store Connect.", comment: "kind:label")
            : String(localized: "It replaces \(count) price changes scheduled in App Store Connect.", comment: "kind:label")
        return "\(summary) \(replaces)"
    }
}
