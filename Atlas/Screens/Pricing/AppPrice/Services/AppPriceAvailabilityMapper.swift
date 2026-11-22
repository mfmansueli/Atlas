//
//  AppPriceAvailabilityMapper.swift
//  Atlas
//

import Foundation

/// Turns App Store Connect's price schedule, price points, availability
/// and territories into Pricing's models.
enum AppPriceAvailabilityMapper {
    /// The schedule's price today. Prices in effect have started (no start
    /// date, or today or before) and haven't ended; the latest start wins.
    /// Apple's proceeds are taken as they are, as for in-app purchases.
    static func currentPrice(
        scheduleID: String,
        baseTerritoryID: String,
        prices: PricingAPIDocument<AppPriceAttributes>,
        today: String
    ) -> AppCurrentPrice {
        let included = prices.includedByKey()
        var best: [String: (start: String, point: PricePoint, currency: String?)] = [:]
        var later = 0
        for price in prices.data {
            guard let territoryID = price.related("territory")?.id else { continue }
            let start = price.attributes.startDate ?? ""
            if start > today {
                if territoryID == baseTerritoryID { later += 1 }
                continue
            }
            guard price.attributes.endDate.map({ $0 > today }) ?? true,
                  let pointID = price.related("appPricePoint"),
                  let customerPrice = LivePricingMapper.decimal(included[pointID]?.attributes?.customerPrice)
            else { continue }
            if let existing = best[territoryID], existing.start > start { continue }
            let point = PricePoint(
                customerPrice: customerPrice,
                proceeds: LivePricingMapper.decimal(included[pointID]?.attributes?.proceeds) ?? 0,
                appStoreConnectID: pointID.id
            )
            let currency = included[PricingAPIIdentifier(type: "territories", id: territoryID)]?.attributes?.currency
            best[territoryID] = (start, point, currency)
        }
        let base = best[baseTerritoryID]
        return AppCurrentPrice(
            scheduleID: scheduleID,
            baseTerritoryID: baseTerritoryID,
            currencyCode: base?.currency ?? AppTerritory(id: baseTerritoryID).currencyCode,
            point: base?.point,
            otherManualTerritoryIDs: best.keys.filter { $0 != baseTerritoryID }.sorted(),
            laterChangeCount: later
        )
    }

    /// One territory's points, lowest first, with Apple's IDs.
    static func ladder(_ document: PricingAPIDocument<SubscriptionPricePointAttributes>, territoryID: String) -> PricePointLadder {
        let currency = document.included?.first { $0.type == "territories" && $0.id == territoryID }?.attributes?.currency
        let points = document.data.compactMap { resource -> PricePoint? in
            guard resource.related("territory").map({ $0.id == territoryID }) ?? true,
                  let price = LivePricingMapper.decimal(resource.attributes.customerPrice)
            else { return nil }
            return PricePoint(customerPrice: price, proceeds: LivePricingMapper.decimal(resource.attributes.proceeds) ?? 0, appStoreConnectID: resource.id)
        }
        return PricePointLadder(territoryID: territoryID, currencyCode: currency ?? AppTerritory(id: territoryID).currencyCode, points: points)
    }

    /// The availability and its countries and regions.
    static func availability(
        id: String,
        availableInNewTerritories: Bool?,
        territories: [AppInformationResourceDocument<TerritoryAvailabilityAttributes>.Resource]
    ) -> AppAvailability {
        AppAvailability(
            id: id,
            availableInNewTerritories: availableInNewTerritories,
            territories: territories.compactMap { resource in
                guard let territoryID = resource.relationshipID("territory") else { return nil }
                return AppTerritoryAvailability(
                    id: resource.id,
                    territoryID: territoryID,
                    isAvailable: resource.attributes.available ?? false,
                    releaseDate: resource.attributes.releaseDate,
                    isPreOrder: resource.attributes.preOrderEnabled ?? false,
                    contentStatuses: resource.attributes.contentStatuses ?? []
                )
            }
        )
    }

    static func territories(_ resources: [AppStoreConnectResource<TerritoryAttributes>]) -> [AppTerritory] {
        AppTerritory.sorted(resources.map { AppTerritory(id: $0.id, currencyCode: $0.attributes.currency) })
    }
}
