//
//  GetPricesTool.swift
//  Atlas
//

import Foundation

/// `get_prices`: an app's pricing mode, and for each product (or one) every
/// territory's price, proceeds, suggestion and queued price.
struct GetPricesTool: MCPTool {
    static let hint = """
    Each territory: `territory` (App Store Connect's three-letter code), `name`, `region`, `currency`, `price` \
    (today's customer price, tax included), `usd` (about that many US dollars, from approximate rates) and \
    `proceeds` (what the developer receives at the commission set in Atlas, after tax), in that currency. \
    `setBy` is how it's set: basePrice, automatic (Apple's price, which follows the base price), setByYou or \
    acceptedSuggestion; `automaticPrice` is Apple's automatic price where today's differs. `suggested` and \
    `reason` appear only when the app shows suggestions and the suggestion differs from today's price; \
    `dismissed` means the person dismissed it, so don't propose it again. `queued` is a price waiting in Review \
    & Push (`queuedAutomatic` when it's Apple's automatic price) and `queuedBy` who proposed it; `alternative` \
    is another assistant's or the person's competing version. Prices \
    must be one of Apple's price points: use get_price_points, then propose_prices (one country, a list, or \
    territories such as "europe", "suggested" or "all").
    """

    let definition = MCPToolDefinition(
        name: "get_prices",
        title: "Get prices",
        description: """
        Reads an app's subscription and in-app purchase prices in every territory: today's price and proceeds, \
        Atlas's suggestion with its reason (when the app shows suggestions) and any price waiting in \
        review, how each is set (base, automatic or chosen) and about how many US dollars it is, plus the app's \
        pricing mode (keepPrices, showSuggestions or applyRecommended). Apps set to keepPrices refuse every price \
        proposal. Pass productId to read one product and territories (codes, "all", a region, "currency:EUR", \
        "suggested", "setByYou", "automatic") to read only those countries; `hint` explains the fields.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "productId": MCPToolDefinition.string("A product's Apple ID, product ID or name. Leave it out for every product."),
            ].merging(MCPCountrySelection.properties) { first, _ in first },
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let selection = try MCPCountrySelection.parse(arguments)
        let products = try arguments.optionalString("productId").map { try [catalog.requireProduct($0)] } ?? catalog.catalog.products
        var entries: [JSONValue] = []
        for product in products {
            let sheet: MCPPriceSheet
            do {
                sheet = try await catalog.sheet(for: product)
            } catch {
                // One product without prices (a new subscription) doesn't hide the others.
                guard products.count > 1 else { throw error }
                entries.append([
                    "productId": .string(product.id),
                    "name": .string(product.name),
                    "sku": .string(product.productID),
                    "unavailable": .string(error.localizedDescription),
                ])
                continue
            }
            var entry = sheet.productJSON
            let countries = sheet.countryRows()
            let shown = selection.map { $0.resolve(in: countries).rows } ?? countries
            let rows = Dictionary(uniqueKeysWithValues: sheet.rows().map { ($0.id, $0) })
            let dismissed = sheet.dismissedSuggestionTerritoryIDs
            entry["territories"] = .array(shown.compactMap { country in
                rows[country.id].map { Self.entry(for: $0, country: country, dismissed: dismissed, in: sheet) }
            })
            entries.append(.object(entry))
        }
        let result: JSONValue = [
            "appId": .string(catalog.app.id),
            "app": .string(catalog.app.name),
            "pricingMode": .string(catalog.mode.rawValue),
            "hint": .string(Self.hint),
            "products": .array(entries),
        ]
        let target = products.count == 1 ? "\(catalog.app.name) · \(products[0].name)" : String(localized: "\(catalog.app.name) · prices")
        return .read(result, target: target)
    }

    /// One territory, leaving out what doesn't apply.
    private static func entry(for row: PricingRow, country: CountryPriceRow, dismissed: Set<String>, in sheet: MCPPriceSheet) -> JSONValue {
        var entry: [String: JSONValue] = [
            "territory": .string(row.territory.id),
            "name": .string(row.territory.name),
            "region": .string(row.territory.region.rawValue),
            "currency": .string(row.territory.currencyCode),
            "price": MCPPriceValue.json(row.current.customerPrice),
            "proceeds": MCPPriceValue.json(row.current.proceeds.rounded(scale: 2)),
            "setBy": .string(country.source.rawValue),
        ]
        if let usd = country.dollars(row.current.customerPrice) { entry["usd"] = MCPPriceValue.json(usd.rounded(scale: 2)) }
        if !country.isBase, PricingRow.differs(country.automatic.customerPrice, row.current.customerPrice) {
            entry["automaticPrice"] = MCPPriceValue.json(country.automatic.customerPrice)
        }
        if let recommendation = row.recommendation, PricingRow.differs(recommendation.price.customerPrice, row.current.customerPrice) {
            entry["suggested"] = MCPPriceValue.json(recommendation.price.customerPrice)
            entry["reason"] = .string(recommendation.reason)
            if dismissed.contains(row.id) { entry["dismissed"] = true }
        }
        if let queued = country.queued {
            entry["queued"] = MCPPriceValue.json(queued.price)
            entry["queuedBy"] = .string(queued.source.title)
            if queued.isAutomatic { entry["queuedAutomatic"] = true }
        }
        if row.queued != nil || country.queued != nil {
            let alternative = sheet.product.isInAppPurchase ? nil : sheet.queuedChange(for: row.territory)?.alternative
            if let alternative, let price = CurrencyFormat.forCurrency(row.territory.currencyCode).parse(alternative.newValue) {
                entry["alternative"] = ["price": MCPPriceValue.json(price), "by": .string(alternative.source.title)]
            }
        }
        return .object(entry)
    }
}
