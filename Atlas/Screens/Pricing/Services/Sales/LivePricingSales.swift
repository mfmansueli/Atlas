//
//  LivePricingSales.swift
//  Atlas
//

import Foundation

/// Pricing's live sales evidence for `LivePricingServices`: what
/// Analytics already downloaded (`AnalyticsStore`), read through
/// `PricingSalesReader`, and the price history. Knows each product's app
/// from the catalogs read, since a price sheet is asked for by product.
@MainActor
final class LivePricingSales {
    let analytics: AnalyticsStore
    let history: PriceChangeHistoryStore
    /// Price tests: their countries' prices aren't read as changes, and
    /// their 28 days are kept for the verdict.
    var tests = PriceTestStore.shared
    /// Settings → Pricing → "Use sales data for suggestions".
    var usesSalesData: () -> Bool = {
        UserDefaults.standard.object(forKey: AppPreferences.usesSalesDataKey) as? Bool ?? true
    }

    var territories = TerritoryCatalog.standard
    var now: () -> Date = { .now }
    private var appIDs: [String: StoreApp.ID] = [:]

    init(analytics: AnalyticsStore? = nil, history: PriceChangeHistoryStore? = nil) {
        self.analytics = analytics ?? .shared
        self.history = history ?? .shared
    }

    /// Remembers which app each product of `catalog` belongs to.
    func register(_ catalog: PricingCatalog, appID: StoreApp.ID) {
        for product in catalog.products {
            appIDs[product.id] = appID
        }
    }

    func appID(of product: PricingProduct) -> StoreApp.ID? {
        appIDs[product.id]
    }

    func reader(for product: PricingProduct, baseTerritoryID: String) -> PricingSalesReader? {
        guard let appID = appIDs[product.id] else { return nil }
        let input = PricingSalesInput(store: analytics, appID: appID, usesSalesData: usesSalesData())
        return PricingSalesReader(input: input, territories: territories, baseTerritoryID: baseTerritoryID)
    }

    /// Puts the product's sales on `sheet`, notes the prices read (a
    /// change made outside Atlas joins the history) and keeps the 28-day
    /// windows of changes the reports now cover. A product whose app isn't
    /// known keeps `.notRead`.
    func fill(_ sheet: inout ProductPriceSheet, product: PricingProduct, startDays: [String: String] = [:]) {
        guard let appID = appIDs[product.id], let reader = reader(for: product, baseTerritoryID: sheet.baseTerritoryID) else { return }
        var sales = reader.salesData(for: product)
        // A running test's price and its return on day 28 are the test's,
        // not price changes of their own.
        let testing = tests.tests(for: appID).filter { $0.productID == product.id && $0.state == .running }
        let readings = readings(of: sheet, startDays: startDays).filter { reading in
            !testing.contains { $0.territoryIDs.contains(reading.key) && $0.windows == nil }
        }
        keepTestWindows(of: product, appID: appID, reader: reader, baseTerritoryID: sheet.baseTerritoryID, canRead: sales.canRead)
        history.update(appID) { history in
            history.noteRead(productID: product.id, prices: readings, at: now())
            guard sales.canRead, let from = reader.coveredFrom, let through = reader.readThrough else { return }
            history.snapshotWindows(productID: product.id, from: from, through: through) { range in
                reader.signals(for: product, in: range)
            }
        }
        if sales.availability == .available {
            sales.priorChanges = history.history(for: appID).priorChanges(productID: product.id)
            sales.priceTests = tests.evidence(for: appID, productID: product.id)
        }
        sheet.sales = sales
    }

    /// A finished test's 28 days before and during, once the reports cover them.
    private func keepTestWindows(of product: PricingProduct, appID: StoreApp.ID, reader: PricingSalesReader, baseTerritoryID: String, canRead: Bool) {
        guard canRead, let from = reader.coveredFrom, let through = reader.readThrough else { return }
        let readOn = now()
        tests.update(appID) { book in
            book.snapshotWindows(productID: product.id, from: from, through: through, baseTerritoryID: baseTerritoryID, readOn: readOn) { range in
                reader.signals(for: product, in: range)
            }
        }
    }

    /// Results: each territory's 28 days either side of a change, the kept
    /// windows first (the archive forgets after 200 days), else read now;
    /// nil when sales can't be read.
    func comparison(for product: PricingProduct, territoryIDs: [String], changedOn date: Date, baseTerritoryID: String) -> [String: SalesComparison]? {
        guard let appID = appIDs[product.id], let reader = reader(for: product, baseTerritoryID: baseTerritoryID),
              var result = reader.comparison(for: product, territoryIDs: territoryIDs, changedOn: date)
        else { return nil }
        let day = AnalyticsDay(date)
        let wanted = Set(territoryIDs)
        for record in history.history(for: appID).records(productID: product.id) where record.day == day && wanted.contains(record.territoryID) {
            guard let before = record.before, let after = record.after else { continue }
            result[record.territoryID] = SalesComparison(before: SalesWindow(signal: before), after: SalesWindow(signal: after))
        }
        return result
    }

    func subscribers(for product: PricingProduct, baseTerritoryID: String) -> [String: Int]? {
        reader(for: product, baseTerritoryID: baseTerritoryID)?.subscribers(for: product)
    }

    func priceHistory(for product: PricingProduct) -> [PriceChangeRecord] {
        guard let appID = appIDs[product.id] else { return [] }
        return history.history(for: appID).records(productID: product.id)
    }

    // MARK: - Private

    private func readings(of sheet: ProductPriceSheet, startDays: [String: String]) -> [String: PriceChangeReading] {
        var result: [String: PriceChangeReading] = [:]
        for (territoryID, price) in sheet.prices {
            guard let territory = territories.territory(alpha3: territoryID) else { continue }
            result[territoryID] = PriceChangeReading(
                price: price.current.customerPrice,
                currencyCode: territory.currencyCode,
                startDate: startDays[territoryID].flatMap { AnalyticsDay(iso: $0)?.date }
            )
        }
        return result
    }
}
