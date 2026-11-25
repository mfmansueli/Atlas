//
//  PricesByCountryDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// A product's Prices by Country (board 73) as DEBUG scenes, on Lumen's
/// fixtures (`PricesByCountryDebugHost`):
///
/// - `pr-prod-edit`: Lumen Plus Annual with Brazil's price popover open.
/// - `pr-prod-set`: Brazil set to its suggested price: was …, Not pushed,
///   Undo and the toast.
/// - `pr-prod-sel`: three suggested countries selected, with the bar.
/// - `pr-prod-find`: "EUR" in Find.
/// - `pr-prod-find-none`: "Atlantis" in Find, which matches nothing.
/// - `pr-prod-life`: Lumen Lifetime, an in-app purchase, with three hand
///   edits (Japan back to automatic), sorted by change.
/// - `pr-prod-rp`: Review & Push with both products' rows.
/// - `pr-prod-narrow`: Lumen Plus Annual narrower than 780 pt.
/// - `pr-prod-none`: Lumen Plus Monthly on Suggested after its suggestion
///   was dismissed: the filter's empty text.
enum PricesByCountryDebugScenes {
    static let ids = [
        "pr-prod-edit", "pr-prod-set", "pr-prod-sel", "pr-prod-find", "pr-prod-find-none", "pr-prod-life", "pr-prod-rp", "pr-prod-narrow",
        "pr-prod-none",
    ]

    private static let annual = DebugPricingCatalog.lumenAnnualID
    private static let lifetime = DebugPricingCatalog.lumenLifetimeID
    private static let monthly = DebugPricingCatalog.lumenMonthlyID

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-edit":
            AnyView(PricesByCountryDebugHost(productID: annual, focusedTerritory: "BRA") { _ in } present: { model in
                guard let row = model.countryRow(productID: annual, territoryID: "BRA") else { return }
                model.pricesByCountry.popover = .opening(row)
            })
        case "pr-prod-set":
            host(annual, focusedTerritory: "BRA") { model in
                guard let row = model.countryRow(productID: annual, territoryID: "BRA") else { return }
                let price = row.suggestion?.customerPrice ?? row.current.customerPrice
                await model.setCountryPrice(.price(price), productID: annual, territoryID: "BRA")
            }
        case "pr-prod-sel":
            host(annual) { model in
                let suggested = (model.countryRows(productID: annual) ?? []).filter(\.hasSuggestion)
                model.pricesByCountry.selection = Set(suggested.prefix(3).map(\.id))
            }
        case "pr-prod-find":
            host(annual) { model in model.pricesByCountry.search = "EUR" }
        case "pr-prod-find-none":
            host(annual) { model in model.pricesByCountry.search = "Atlantis" }
        case "pr-prod-life":
            host(lifetime, prepare: lifetimeEdits)
        case "pr-prod-rp":
            AnyView(DebugMainScene(services: .debug, pendingChanges: reviewChanges(), presentedSheet: .review))
        case "pr-prod-narrow":
            host(annual, size: CGSize(width: 740, height: 600))
        case "pr-prod-none":
            AnyView(PricesByCountryDebugHost(productID: monthly, filter: .suggested) { model in
                model.dismissPriceSuggestion(productID: monthly)
            })
        default:
            nil
        }
    }

    @MainActor
    private static func host(
        _ productID: String,
        size: CGSize = CGSize(width: 1000, height: 640),
        focusedTerritory: String? = nil,
        prepare: @escaping @MainActor (PricingViewModel) async -> Void = { _ in }
    ) -> AnyView {
        AnyView(PricesByCountryDebugHost(productID: productID, size: size, focusedTerritory: focusedTerritory, prepare: prepare))
    }

    /// Brazil and India lower by hand and Japan back to automatic, the
    /// biggest drop first.
    @MainActor
    private static func lifetimeEdits(_ model: PricingViewModel) async {
        guard let matrix = model.countriesMatrix(productID: lifetime) else { return }
        let edits = handEdits(sheet: matrix.sheet, automatic: "JPN")
        model.write(edits, matrix: matrix, source: .you)
        model.pricesByCountry.sortOrder = [KeyPathComparator(\CountryPriceRow.changeSortKey)]
    }

    /// A few points below today's in Brazil and India, and one country
    /// back to Apple's automatic price.
    private static func handEdits(sheet: ProductPriceSheet, automatic: String) -> [String: CountryPriceEdit] {
        var edits: [String: CountryPriceEdit] = [automatic: .automatic]
        for territoryID in ["BRA", "IND"] {
            guard let current = sheet.prices[territoryID]?.current.customerPrice,
                  let points = sheet.ladders[territoryID]?.points,
                  let index = points.firstIndex(where: { !PricingRow.differs($0.customerPrice, current) }) ?? points.indices.last
            else { continue }
            edits[territoryID] = .price(points[max(0, index - 4)].customerPrice)
        }
        return edits
    }

    /// Lumen Plus Annual's and Lumen Lifetime's hand edits, as Prices by
    /// Country queues them: one row per product.
    @MainActor
    private static func reviewChanges() -> [PendingChange] {
        let app = DebugFixtures.lumen
        let catalog = DebugPricingCatalog.catalog(for: app.id)
        let queue = ChangeQueue()
        if let product = catalog.product(id: annual) {
            let sheet = DebugPriceSheets.sheet(for: product, commission: .smallBusiness, canReadSales: true)
            let factory = PriceChangeFactory(appID: app.id, product: product, schedule: .immediate)
            for (territoryID, edit) in handEdits(sheet: sheet, automatic: "MEX") {
                guard let territory = TerritoryCatalog.standard.territory(alpha3: territoryID), let price = sheet.prices[territoryID] else { continue }
                let isAutomatic = edit == .automatic
                let point: PricePoint? = switch edit {
                case .automatic: price.equalized
                case let .price(value): sheet.ladders[territoryID]?.point(at: value)
                }
                guard let point else { continue }
                let change = factory.change(for: territory, from: price.current, to: point, source: .you)
                queue.upsert(PricesByCountryChanges.decorated(
                    change, product: product, territory: territory, old: price.current.customerPrice, new: point.customerPrice, isAutomatic: isAutomatic
                ))
            }
            PricesByCountryChanges.refreshSummary(in: queue, appID: app.id, product: product)
        }
        if let product = catalog.product(id: lifetime) {
            let sheet = DebugPriceSheets.sheet(for: product, commission: .smallBusiness, canReadSales: true)
            let builder = InAppPurchaseCountryPrices(appID: app.id, product: product, sheet: sheet)
            if let change = builder.change(edits: handEdits(sheet: sheet, automatic: "JPN"), ladder: { sheet.ladders[$0] }, source: .you) {
                queue.upsert(change)
            }
        }
        return queue.changes
    }
}
#endif
