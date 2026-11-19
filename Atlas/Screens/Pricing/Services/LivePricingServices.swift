//
//  LivePricingServices.swift
//  Atlas
//

import Foundation

/// The real `PricingServices`, backed by App Store Connect. Sales and Trends
/// aren't read, so live suggestions use purchasing power alone.
@MainActor
struct LivePricingServices: PricingServices {
    let client: AppStoreConnectClient
    let cache = LivePricingCache()
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
                    result.groups[groupIndex].products[productIndex].basePrice = try await basePrice(of: product)
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
        sheet.merge(cache.ladders(for: cacheKey(product, commission), territoryIDs: Array(sheet.prices.keys)))
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
        let current = try await LivePricingMapper.currentInAppPurchasePrices(
            manual: client.inAppPurchasePrices(scheduleID: scheduleID, automatic: false),
            automatic: client.inAppPurchasePrices(scheduleID: scheduleID, automatic: true),
            commission: commission,
            today: dayString(today())
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
        sheet.merge(cache.ladders(for: cacheKey(product, commission), territoryIDs: Array(sheet.prices.keys)))
        return sheet
    }

    func ladders(for product: PricingProduct, territoryIDs: [String], commission: Commission) async throws -> [String: PricePointLadder] {
        let key = cacheKey(product, commission)
        var result = cache.ladders(for: key, territoryIDs: territoryIDs)
        let missing = territoryIDs.filter { result[$0] == nil }
        var start = missing.startIndex
        while start < missing.endIndex {
            let end = min(start + AppStoreConnectClient.pricePointTerritoryBatch, missing.endIndex)
            let batch = Array(missing[start..<end])
            let points = if product.isInAppPurchase {
                try await LivePricingMapper.inAppPurchasePointsByTerritory(
                    client.inAppPurchasePricePoints(purchaseID: product.id, territoryIDs: batch), commission: commission
                )
            } else {
                try await LivePricingMapper.pointsByTerritory(
                    client.subscriptionPricePoints(subscriptionID: product.id, territoryIDs: batch), commission: commission
                )
            }
            var fetched: [String: PricePointLadder] = [:]
            for (territoryID, points) in points {
                guard let territory = catalog.territory(alpha3: territoryID) else { continue }
                fetched[territoryID] = PricePointLadder(territoryID: territoryID, currencyCode: territory.currencyCode, points: points)
            }
            cache.store(fetched, for: key)
            result.merge(fetched) { _, new in new }
            start = end
        }
        return result
    }

    // MARK: - Private

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

    private func cacheKey(_ product: PricingProduct, _ commission: Commission) -> String {
        product.id + "." + commission.rawValue
    }

    private func dayString(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }
}
