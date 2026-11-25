//
//  MCPPriceSheet.swift
//  Atlas
//

import Foundation

/// One product's prices as the price tools read and propose them: each
/// territory's price, proceeds, suggestion (with the app's own strategy,
/// the one Pricing shows: Customize… or Settings → Pricing's defaults)
/// and queued price, Apple's price points, and the pending changes a
/// proposal becomes, built like the Pricing screen builds them.
@MainActor
struct MCPPriceSheet {
    let app: StoreApp
    let product: PricingProduct
    let mode: PricingMode
    private(set) var sheet: ProductPriceSheet
    let calculator: PriceCalculator
    let workspace: MCPWorkspace

    var territories: TerritoryCatalog { .standard }

    /// The strategy Pricing suggests this app's prices with.
    var strategy: PricingStrategy { workspace.pricingModes.strategy(for: app.id) }

    /// In-app purchases and Keep my prices show prices without suggestions.
    var showsSuggestions: Bool { mode.showsSuggestions && !product.isInAppPurchase }

    /// Every territory with a price, in catalog order.
    func rows() -> [PricingRow] {
        rowBuilder.rows(queued: queuedPrices())
    }

    /// Builds the rows, and each territory's calculation input, from the
    /// base price waiting in Review & Push when there is one.
    var rowBuilder: PricingRowBuilder {
        var builder = PricingRowBuilder(
            catalog: territories,
            calculator: calculator,
            sheet: sheet,
            strategy: strategy,
            showsSuggestions: showsSuggestions
        )
        builder.queuedBasePrice = queuedPrices()[sheet.baseTerritoryID]?.price
        return builder
    }

    /// The territory an assistant means: its alpha-3 or alpha-2 code, or
    /// its name (case ignored), when the product has a price there.
    func territory(matching identifier: String) -> Territory? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let territory = territories.territory(code: trimmed.uppercased())
            ?? territories.territories.first { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return territory.flatMap { sheet.prices[$0.id] == nil ? nil : $0 }
    }

    func ladder(for territory: Territory) -> PricePointLadder {
        sheet.ladder(for: territory, commission: calculator.commission)
    }

    /// Loads Apple's own price points where the sheet only has simulated
    /// ones, since only Apple's points can be pushed.
    mutating func loadExactLadders(for territoryIDs: [String]) async throws {
        let missing = sheet.missingLadders(in: territoryIDs)
        guard !missing.isEmpty else { return }
        do {
            let ladders = try await workspace.services.pricing.ladders(for: product, territoryIDs: missing, commission: calculator.commission)
            sheet.merge(ladders)
        } catch {
            let what = String(localized: "Apple’s price points for \(product.name) didn’t load.", comment: "kind:other")
            throw MCPToolError.unavailable(AppleErrorCopy(what, error: error).text)
        }
    }

    /// "Lumen Journal · Lumen Plus Annual".
    var target: String {
        "\(app.name) · \(product.name)"
    }

    /// "Lumen Journal · Lumen Plus Annual · Brazil".
    func target(_ territoryName: String) -> String {
        "\(target) · \(territoryName)"
    }

    /// The product's identity in tool results.
    var productJSON: [String: JSONValue] {
        var json: [String: JSONValue] = [
            "productId": .string(product.id),
            "name": .string(product.name),
            "sku": .string(product.productID),
            "inAppPurchase": .bool(product.isInAppPurchase),
            "baseTerritory": .string(sheet.baseTerritoryID),
        ]
        if let period = product.period { json["period"] = .string(period.title) }
        return json
    }

    // MARK: - Queue

    /// The queued change of one territory, if any.
    func queuedChange(for territory: Territory) -> PendingChange? {
        workspace.changes.change(id: PriceChangeFactory.changeID(productID: product.id, territoryID: territory.id))
    }

    /// A pending change setting `territory` to `point`, on the schedule the
    /// product's other queued changes follow, waiting under the product's
    /// one Review & Push row as Prices by Country's do.
    func change(for territory: Territory, to point: PricePoint, source: ChangeSource) -> PendingChange? {
        guard let price = sheet.prices[territory.id] else { return nil }
        let schedule = PriceSchedule.current(in: workspace.changes, appID: app.id, productID: product.id)
        let change = PriceChangeFactory(appID: app.id, product: product, schedule: schedule)
            .change(for: territory, from: price.current, to: point, source: source)
        let isBase = territory.id == sheet.baseTerritoryID
        return PricesByCountryChanges.decorated(
            change,
            product: product,
            territory: territory,
            old: price.current.customerPrice,
            new: point.customerPrice,
            isAutomatic: !isBase && !PricingRow.differs(point.customerPrice, price.equalized.customerPrice)
        )
    }

    /// Rewrites the line under the product's Review & Push row after its
    /// subscription changes moved.
    func refreshSummary() {
        guard !product.isInAppPurchase else { return }
        PricesByCountryChanges.refreshSummary(in: workspace.changes, appID: app.id, product: product)
    }

    private func queuedPrices() -> [String: QueuedPrice] {
        let prefix = PriceChangeFactory.changeID(productID: product.id, territoryID: "")
        var result: [String: QueuedPrice] = [:]
        for change in workspace.changes.changes(for: app.id, section: .subscriptionPricing) where change.id.hasPrefix(prefix) {
            let territoryID = String(change.id.dropFirst(prefix.count))
            guard let territory = territories.territory(alpha3: territoryID) else { continue }
            result[territoryID] = QueuedPrice(change: change, territory: territory)
        }
        return result
    }
}
