//
//  LivePricingMapper+InAppPurchases.swift
//  Atlas
//

import Foundation

/// An in-app purchase's prices: a schedule of manual prices (the base
/// territory's and any set by hand) and automatic ones (Apple's equalized
/// prices everywhere else), with price points whose proceeds are the
/// account's own.
extension LivePricingMapper {
    /// Today's price per territory: the one in effect (started, not ended),
    /// a manual one over Apple's automatic one.
    static func currentInAppPurchasePrices(
        manual: PricingAPIDocument<InAppPurchasePriceAttributes>,
        automatic: PricingAPIDocument<InAppPurchasePriceAttributes>,
        commission: Commission,
        today: String
    ) -> [String: PricePoint] {
        let automaticPrices = inEffect(automatic, commission: commission, today: today)
        return automaticPrices.merging(inEffect(manual, commission: commission, today: today)) { _, manual in manual }
    }

    /// Price points grouped by territory, from a price point or
    /// equalization response.
    static func inAppPurchasePointsByTerritory(
        _ document: PricingAPIDocument<SubscriptionPricePointAttributes>,
        commission: Commission
    ) -> [String: [PricePoint]] {
        var result: [String: [PricePoint]] = [:]
        for resource in document.data {
            guard let territoryID = resource.related("territory")?.id,
                  let point = inAppPurchasePricePoint(
                      id: resource.id, customerPrice: resource.attributes.customerPrice, proceeds: resource.attributes.proceeds, commission: commission
                  )
            else { continue }
            result[territoryID, default: []].append(point)
        }
        return result
    }

    /// Apple's proceeds as they are, whatever `commission` says: in-app
    /// purchase points have no `proceedsYear2`, and their `proceeds` are
    /// the account's own rate already (SimProps Pro, Small Business
    /// Program: $29.99 → $25.49, 85%). Scaling them by 0.85 ⁄ 0.70 showed
    /// $30.95, more than the price.
    static func inAppPurchasePricePoint(id: String, customerPrice: String?, proceeds: String?, commission _: Commission) -> PricePoint? {
        guard let price = decimal(customerPrice) else { return nil }
        return PricePoint(customerPrice: price, proceeds: decimal(proceeds) ?? 0, appStoreConnectID: id)
    }

    /// The territories with a manual price in effect today: the base
    /// territory and any set by hand. The others follow Apple's automatic
    /// price.
    static func inAppPurchaseManualTerritoryIDs(
        _ manual: PricingAPIDocument<InAppPurchasePriceAttributes>,
        commission: Commission,
        today: String
    ) -> Set<String> {
        Set(inEffect(manual, commission: commission, today: today).keys)
    }

    /// Manual prices that start after today: a new schedule replaces them.
    static func laterInAppPurchasePriceCount(_ manual: PricingAPIDocument<InAppPurchasePriceAttributes>, today: String) -> Int {
        manual.data.count { ($0.attributes.startDate ?? "") > today }
    }

    // MARK: - Private

    private static func inEffect(
        _ document: PricingAPIDocument<InAppPurchasePriceAttributes>,
        commission: Commission,
        today: String
    ) -> [String: PricePoint] {
        let included = document.includedByKey()
        var best: [String: (start: String, point: PricePoint)] = [:]
        for price in document.data {
            let start = price.attributes.startDate ?? ""
            guard start <= today,
                  price.attributes.endDate.map({ $0 > today }) ?? true,
                  let territoryID = price.related("territory")?.id,
                  let pointID = price.related("inAppPurchasePricePoint"),
                  let point = inAppPurchasePricePoint(
                      id: pointID.id,
                      customerPrice: included[pointID]?.attributes?.customerPrice,
                      proceeds: included[pointID]?.attributes?.proceeds,
                      commission: commission
                  )
            else { continue }
            if let existing = best[territoryID], existing.start > start { continue }
            best[territoryID] = (start, point)
        }
        return best.mapValues(\.point)
    }
}
