//
//  DebugPricingServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// `PricingServices` for DEBUG scenes: the sample apps' canned data, or
/// `error`. Never contacts App Store Connect.
@MainActor
struct DebugPricingServices: PricingServices {
    var error: AppStoreConnectError?
    /// Thrown by price sheets alone, e.g. `PricingSheetError.noStartingPrice`.
    var sheetError: PricingSheetError?
    /// How long a price sheet takes to arrive; long enough keeps the skeleton up.
    var sheetDelay: Duration?
    /// How long the summary (Overview's cards) takes, for overview-loading.
    var summaryDelay: Duration?
    /// Answers the first sheet at once and delays only the ones after it (a refresh).
    var delaysRefreshOnly = false
    /// False plays a key whose role can't read Sales and Trends.
    var canReadSales = true
    /// The state a scene opens in once prices have loaded.
    var launch: PricingDebugLaunch?
    /// The index a scene prices by instead of the sample (`pr-prod-index*`
    /// use the real bundled one).
    var snapshot: PriceIndexSnapshot?
    /// Sheets arrive on simulated ladders, as App Store Connect's do until
    /// Apple's price points are read (`pr-prod-checking`).
    var simulatesGrid = false
    /// How long Apple's price points take to arrive.
    var laddersDelay: Duration?
    /// Thrown by price point reads alone (`pr-prod-grid-error`).
    var laddersError: AppStoreConnectError?
    /// Lumen Plus Annual's sales in place of the sample's
    /// (`DebugPricingSales`, `pr-prod-sales*`).
    var sales: PricingSalesData?
    /// The price history Results reads; when set, its kept windows are the
    /// sales Results compare (`pr-prod-results-read`).
    var priceChanges: [PriceChangeRecord] = []
    /// When Apple's price points read for every territory, for
    /// get_prices' grid; nil keeps no read date.
    var laddersReadOn: Date?
    let calls = DebugPricingCallLog()

    func summary(for app: StoreApp) async throws -> PricingSummary {
        if let summaryDelay { try await Task.sleep(for: summaryDelay) }
        if let error { throw error }
        return DebugSummaries.pricing(for: app.id)
    }

    func catalog(for app: StoreApp) async throws -> PricingCatalog {
        if let error { throw error }
        return DebugPricingCatalog.catalog(for: app.id)
    }

    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        let request = calls.recordSheetRequest()
        if let sheetDelay, !delaysRefreshOnly || request > 1 { try await Task.sleep(for: sheetDelay) }
        if let error { throw error }
        if let sheetError { throw sheetError }
        var sheet = DebugPriceSheets.sheet(for: product, commission: commission, canReadSales: canReadSales)
        if simulatesGrid { sheet.exactLadderIDs = [] }
        if let sales, isLumenAnnual(product) { sheet.sales = sales }
        return sheet
    }

    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        calls.recordLadderRequest(territoryIDs)
        if let laddersDelay { try await Task.sleep(for: laddersDelay) }
        if let laddersError { throw laddersError }
        let ladders = DebugPriceSheets.sheet(for: product, commission: commission, canReadSales: canReadSales).ladders
        return ladders.filter { territoryIDs.contains($0.key) }
    }

    /// Every territory read on `laddersReadOn`, when it's set.
    func ladderReadDates(for _: String, commission _: Commission) -> [String: Date] {
        guard let laddersReadOn else { return [:] }
        return Dictionary(uniqueKeysWithValues: TerritoryCatalog.standard.territories.map { ($0.id, laddersReadOn) })
    }

    /// Notes what a push asked to drop; DEBUG services keep no ladders.
    func forgetLadders(for productID: String, fetchedBefore date: Date) async {
        calls.recordForget(productID: productID, before: date)
    }

    /// Lumen Plus Annual's offers; other products have none.
    func offers(for product: PricingProduct) async throws -> [SubscriptionOffer] {
        if let error { throw error }
        return isLumenAnnual(product) ? PricingSampleData.offers : []
    }

    /// Lumen Plus Annual's existing subscribers; other products have none.
    func subscribers(for product: PricingProduct) async throws -> [String: Int]? {
        if let error { throw error }
        return isLumenAnnual(product) ? DebugPricingResults.subscribers() : [:]
    }

    /// Lumen Plus Annual's sales around the sample push; nil for a key that
    /// can't read sales.
    func salesComparison(for product: PricingProduct, territoryIDs: [String], changedOn _: Date) async throws -> [String: SalesComparison]? {
        if let error { throw error }
        guard canReadSales else { return nil }
        guard isLumenAnnual(product) else { return [:] }
        if !priceChanges.isEmpty {
            var kept: [String: SalesComparison] = [:]
            for record in priceChanges where territoryIDs.contains(record.territoryID) {
                guard let before = record.before, let after = record.after else { continue }
                kept[record.territoryID] = SalesComparison(before: SalesWindow(signal: before), after: SalesWindow(signal: after))
            }
            return kept
        }
        return DebugPricingResults.salesComparison().filter { territoryIDs.contains($0.key) }
    }

    func priceHistory(for product: PricingProduct) -> [PriceChangeRecord] {
        priceChanges.filter { $0.productID == product.id }.sorted { $0.date > $1.date }
    }

    /// The sample snapshot, which already holds the imported custom index,
    /// unless the scene set `snapshot`.
    func indexSnapshot() -> PriceIndexSnapshot {
        snapshot ?? PricingSampleData.shared.snapshot
    }

    private func isLumenAnnual(_ product: PricingProduct) -> Bool {
        product.id == DebugPricingCatalog.lumenAnnualID
    }
}
#endif
