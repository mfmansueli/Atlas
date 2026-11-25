//
//  PriceChangeHistory+Push.swift
//  Atlas
//

import Foundation

extension PriceChangeHistory {
    /// The subscription price changes a finished push made, one per
    /// subscription and territory (`PriceChangeFactory`'s ids), dated by
    /// the schedule's start day when it has one, else by the push. An
    /// in-app purchase's new schedule isn't one territory's change: the
    /// next read records what changed.
    static func records(in push: PushRecord, territories: TerritoryCatalog = .standard) -> [PriceChangeRecord] {
        push.pushed.compactMap { change in
            guard change.section == .subscriptionPricing, let ids = ids(of: change.id),
                  let territory = territories.territory(alpha3: ids.territoryID) else { return nil }
            let currency = CurrencyFormat.forCurrency(territory.currencyCode)
            guard let old = currency.parse(change.oldValue), let new = currency.parse(change.newValue) else { return nil }
            return PriceChangeRecord(
                productID: ids.productID,
                territoryID: ids.territoryID,
                date: startDate(of: change) ?? push.date,
                oldPrice: old,
                newPrice: new,
                currencyCode: territory.currencyCode,
                origin: .pushed,
                recordedOn: push.date,
                pushID: push.id
            )
        }
    }

    /// "price.<product>.<territory>" → its product and territory.
    static func ids(of changeID: PendingChange.ID) -> (productID: String, territoryID: String)? {
        let prefix = PriceChangeFactory.changeID(productID: "", territoryID: "").dropLast()
        guard changeID.hasPrefix(prefix) else { return nil }
        let rest = changeID.dropFirst(prefix.count)
        guard let dot = rest.lastIndex(of: "."), dot != rest.startIndex else { return nil }
        let productID = String(rest[..<dot])
        let territoryID = String(rest[rest.index(after: dot)...])
        guard !productID.isEmpty, !territoryID.isEmpty else { return nil }
        return (productID, territoryID)
    }

    /// The scheduled start day in the change's `POST /v1/subscriptionPrices`.
    private static func startDate(of change: PendingChange) -> Date? {
        guard let body = change.requests.first(where: { $0.path == "/v1/subscriptionPrices" })?.body,
              let request = try? JSONDecoder().decode(SubscriptionPriceCreateRequest.self, from: body),
              let day = request.data.attributes.startDate
        else { return nil }
        return AnalyticsDay(iso: day)?.date
    }
}
