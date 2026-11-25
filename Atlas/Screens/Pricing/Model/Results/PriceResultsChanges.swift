//
//  PriceResultsChanges.swift
//  Atlas
//

import Foundation

/// Which change Results compares for a product: the newer of its last push
/// and the last change read from App Store Connect (made there, or on
/// another Mac). A change read on the push's day is that push.
enum PriceResultsChanges {
    /// The change's date and its territories, by territory ID; nil when
    /// the product's prices never changed.
    static func latest(
        product: PricingProduct,
        appID: StoreApp.ID,
        records: [PushRecord],
        history: [PriceChangeRecord],
        territories: TerritoryCatalog = .standard
    ) -> (date: Date, entries: [String: PriceResultsEntry])? {
        let prefix = PriceChangeFactory.changeID(productID: product.id, territoryID: "")
        let push = records
            .filter { $0.appID == appID }
            .sorted { $0.date > $1.date }
            .first { record in record.pushed.contains { $0.id.hasPrefix(prefix) } }
        let reads = history.filter { $0.productID == product.id && $0.origin == .read }
        let lastRead = reads.max { $0.date < $1.date }
        if let push, lastRead.map({ $0.day <= AnalyticsDay(push.date) }) ?? true {
            return pushed(push, prefix: prefix, history: history, territories: territories)
        }
        guard let lastRead else { return nil }
        var entries: [String: PriceResultsEntry] = [:]
        for record in reads where record.day == lastRead.day {
            entries[record.territoryID] = PriceResultsEntry(territoryID: record.territoryID, oldPrice: record.oldPrice, newPrice: record.newPrice)
        }
        return (lastRead.date, entries)
    }

    /// A push's territories, dated by the start day it scheduled, which the
    /// history keeps, else by the push.
    private static func pushed(
        _ push: PushRecord, prefix: String, history: [PriceChangeRecord], territories: TerritoryCatalog
    ) -> (date: Date, entries: [String: PriceResultsEntry]) {
        var entries: [String: PriceResultsEntry] = [:]
        for change in push.pushed where change.id.hasPrefix(prefix) {
            let territoryID = String(change.id.dropFirst(prefix.count))
            guard let territory = territories.territory(alpha3: territoryID) else { continue }
            let currency = CurrencyFormat.forCurrency(territory.currencyCode)
            guard let old = currency.parse(change.oldValue), let new = currency.parse(change.newValue) else { continue }
            entries[territoryID] = PriceResultsEntry(territoryID: territoryID, oldPrice: old, newPrice: new, pushed: change)
        }
        let date = history.first { $0.pushID == push.id }?.date ?? push.date
        return (date, entries)
    }
}
