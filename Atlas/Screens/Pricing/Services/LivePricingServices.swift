//
//  LivePricingServices.swift
//  Atlas
//

import Foundation

/// The real `PricingServices`, backed by App Store Connect, with the sales
/// Analytics already downloaded (`LivePricingSales`). Apple's price point
/// ladders are kept in `cache` (memory and this Mac), which the Pricing
/// screen, get_price_points and the push all read through
/// `ladders(for:territoryIDs:commission:)`.
@MainActor
struct LivePricingServices: PricingServices {
    let client: AppStoreConnectClient
    var cache = LivePricingCache()
    /// App Analytics and Sales and Trends from `AnalyticsStore`, and the
    /// price history.
    let sales = LivePricingSales()
    var catalog = TerritoryCatalog.standard
    var baseTerritoryID = "USA"
    var today: () -> Date = { .now }

    func summary(for app: StoreApp) async throws -> PricingSummary {
        let catalog = try await catalog(for: app)
        guard let product = Self.reportedProduct(in: catalog) else {
            return PricingSummaryBuilder(catalog: catalog, sheet: nil).summary()
        }
        let sheet: ProductPriceSheet? = if product.isInAppPurchase {
            // Shown, never changed: one without a price yet is no failure.
            try? await priceSheet(for: product, commission: .smallBusiness)
        } else {
            try await priceSheet(for: product, commission: .smallBusiness)
        }
        return PricingSummaryBuilder(catalog: catalog, sheet: sheet, territories: self.catalog).summary()
    }

    /// The product the Overview's territory numbers describe: the annual
    /// subscription, else the first; an app without subscriptions (SimProps)
    /// reports its first in-app purchase with a price, not a free trial.
    static func reportedProduct(in catalog: PricingCatalog) -> PricingProduct? {
        if let subscription = catalog.defaultProduct, !subscription.isInAppPurchase { return subscription }
        return catalog.inAppPurchases.first { ($0.basePrice ?? 0) > 0 }
    }

    func catalog(for app: StoreApp) async throws -> PricingCatalog {
        let groups = try await client.pricedSubscriptionGroups(appID: app.id)
        let purchases = try await client.pricedInAppPurchases(appID: app.id)
        var result = LivePricingMapper.catalog(groups: groups, inAppPurchases: purchases)
        sales.register(result, appID: app.id)
        for groupIndex in result.groups.indices {
            for productIndex in result.groups[groupIndex].products.indices {
                let product = result.groups[groupIndex].products[productIndex]
                if product.isInAppPurchase {
                    // Its card and the Overview show it; one that can't be
                    // read says why when it's opened, not by failing the list.
                    guard let base = try? await inAppPurchaseBasePrice(of: product) else { continue }
                    result.groups[groupIndex].products[productIndex].basePrice = base.price
                    result.groups[groupIndex].products[productIndex].baseCurrencyCode = base.currencyCode
                } else {
                    result.groups[groupIndex].products[productIndex].basePrice = try await basePriceUnlessServerFails(of: product)
                }
            }
        }
        return result
    }

    func priceSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        guard !product.isInAppPurchase else { return try await inAppPurchaseSheet(for: product, commission: commission) }
        let prices = try await client.subscriptionPrices(subscriptionID: product.id)
        let current = LivePricingMapper.currentPrices(prices, commission: commission, today: dayString(today()))
        guard let basePointID = current[baseTerritoryID]?.appStoreConnectID else {
            throw PricingSheetError.noStartingPrice(productName: product.name)
        }
        let equalized = try await LivePricingMapper.pointsByTerritory(client.equalizations(pricePointID: basePointID), commission: commission)
        guard var sheet = LivePricingMapper.sheet(
            product: product,
            current: current,
            equalized: equalized,
            baseTerritoryID: baseTerritoryID,
            catalog: catalog,
            commission: commission
        ) else {
            throw AppStoreConnectError.unexpectedPayload
        }
        await sheet.merge(cache.ladders(for: product.id, commission: commission, territoryIDs: sheet.prices.keys))
        sales.fill(&sheet, product: product, startDays: LivePricingMapper.currentStartDays(prices, today: dayString(today())))
        return sheet
    }

    /// An in-app purchase's prices, shown and never changed: its schedule's
    /// manual and automatic prices in effect today, equalized from its base
    /// territory. Before, Pricing threw "couldn't find that resource. Prices
    /// for in-app purchases aren't shown yet." for each of SimProps's four.
    private func inAppPurchaseSheet(for product: PricingProduct, commission: Commission) async throws -> ProductPriceSheet {
        guard let schedule = try await client.inAppPurchasePriceSchedule(purchaseID: product.id), let scheduleID = schedule.data?.id else {
            throw PricingSheetError.noInAppPurchasePrice(productName: product.name)
        }
        let baseID = schedule.baseTerritoryID ?? baseTerritoryID
        let day = dayString(today())
        let manual = try await client.inAppPurchasePrices(scheduleID: scheduleID, automatic: false)
        let current = try await LivePricingMapper.currentInAppPurchasePrices(
            manual: manual,
            automatic: client.inAppPurchasePrices(scheduleID: scheduleID, automatic: true),
            commission: commission,
            today: day
        )
        guard let basePointID = current[baseID]?.appStoreConnectID else {
            throw PricingSheetError.noInAppPurchasePrice(productName: product.name)
        }
        let equalized = try await LivePricingMapper.inAppPurchasePointsByTerritory(
            client.inAppPurchaseEqualizations(pricePointID: basePointID), commission: commission
        )
        guard var sheet = LivePricingMapper.sheet(
            product: product, current: current, equalized: equalized, baseTerritoryID: baseID, catalog: catalog, commission: commission
        ) else {
            throw AppStoreConnectError.unexpectedPayload
        }
        // Prices by Country tells hand-set prices from Apple's automatic
        // ones, and a new schedule keeps the hand-set ones.
        sheet.manualTerritoryIDs = LivePricingMapper.inAppPurchaseManualTerritoryIDs(manual, commission: commission, today: day)
        sheet.laterManualPriceCount = LivePricingMapper.laterInAppPurchasePriceCount(manual, today: day)
        await sheet.merge(cache.ladders(for: product.id, commission: commission, territoryIDs: sheet.prices.keys))
        sales.fill(&sheet, product: product)
        return sheet
    }

    /// Apple's ladders for the territories: the cached ones, then the rest
    /// from App Store Connect in batches of
    /// `AppStoreConnectClient.pricePointTerritoryBatch`, each kept as it
    /// arrives so a read that fails partway keeps what it got. One read
    /// at a time per product: a second caller waits and reads only what
    /// the first didn't.
    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        try await cache.serialized(productID: product.id) {
            var result = await cache.ladders(for: product.id, commission: commission, territoryIDs: territoryIDs)
            let missing = territoryIDs.filter { result[$0] == nil }
            for batch in Self.batches(missing) {
                let fetched = try await fetchLadders(of: product, territoryIDs: batch, commission: commission)
                cache.store(fetched, for: product.id, commission: commission)
                result.merge(fetched) { _, new in new }
            }
            return result
        }
    }

    /// When each kept ladder of the product was read.
    func ladderReadDates(for productID: String, commission: Commission) -> [String: Date] {
        cache.fetchDates(productID: productID, commission: commission)
    }

    /// After a push that changed the product's prices.
    func forgetLadders(for productID: String, fetchedBefore date: Date) async {
        await cache.forget(productID: productID, fetchedBefore: date)
    }

    /// The territories in request-sized batches, in order, without repeats.
    static func batches(_ territoryIDs: [String], size: Int = AppStoreConnectClient.pricePointTerritoryBatch) -> [[String]] {
        var seen = Set<String>()
        let unique = territoryIDs.filter { seen.insert($0).inserted }
        return stride(from: 0, to: unique.count, by: max(size, 1)).map { start in
            Array(unique[start..<min(start + max(size, 1), unique.count)])
        }
    }

    // MARK: - Private

    /// A subscription's base price, or nil when Apple's server still fails
    /// on it after the retries: its card shows the price its own read finds
    /// (or says that read failed), and the other products still show.
    /// Offline and the hourly limit still fail the list.
    private func basePriceUnlessServerFails(of product: PricingProduct) async throws -> Decimal? {
        do {
            return try await basePrice(of: product)
        } catch let error as AppStoreConnectError where error.isServerFailure {
            return nil
        }
    }

    private func basePrice(of product: PricingProduct) async throws -> Decimal? {
        let prices = try await client.subscriptionPrices(subscriptionID: product.id, territoryID: baseTerritoryID)
        return LivePricingMapper.currentPrices(prices, commission: .standard, today: dayString(today()))[baseTerritoryID]?.customerPrice
    }

    /// An in-app purchase's price in its schedule's base territory, set by
    /// hand there: nil without a schedule or a price today.
    private func inAppPurchaseBasePrice(of product: PricingProduct) async throws -> (price: Decimal, currencyCode: String)? {
        guard let schedule = try await client.inAppPurchasePriceSchedule(purchaseID: product.id), let scheduleID = schedule.data?.id else {
            return nil
        }
        let baseID = schedule.baseTerritoryID ?? baseTerritoryID
        let current = try await LivePricingMapper.currentInAppPurchasePrices(
            manual: client.inAppPurchasePrices(scheduleID: scheduleID, automatic: false, territoryID: baseID),
            automatic: PricingAPIDocument(data: [], included: []),
            commission: .standard,
            today: dayString(today())
        )
        guard let price = current[baseID]?.customerPrice else { return nil }
        return (price, catalog.territory(alpha3: baseID)?.currencyCode ?? "USD")
    }

    /// One batch of territories' ladders. Subscription proceeds follow the
    /// commission (`LivePricingMapper.pricePoint`: `proceedsYear2` in the
    /// Small Business Program, `proceeds` at 30%); an in-app purchase's
    /// are the account's own rate already and are never rescaled.
    private func fetchLadders(of product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        let points = if product.isInAppPurchase {
            try await LivePricingMapper.inAppPurchasePointsByTerritory(
                client.inAppPurchasePricePoints(purchaseID: product.id, territoryIDs: territoryIDs), commission: commission
            )
        } else {
            try await LivePricingMapper.pointsByTerritory(
                client.subscriptionPricePoints(subscriptionID: product.id, territoryIDs: territoryIDs), commission: commission
            )
        }
        var fetched: [String: PricePointLadder] = [:]
        for (territoryID, points) in points {
            guard let territory = catalog.territory(alpha3: territoryID) else { continue }
            fetched[territoryID] = PricePointLadder(territoryID: territoryID, currencyCode: territory.currencyCode, points: points)
        }
        return fetched
    }

    private func dayString(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }
}
