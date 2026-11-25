//
//  GetPricePointsTool.swift
//  Atlas
//

import Foundation

/// `get_price_points`: Apple's price points around a price in one
/// territory or several, since only those can be proposed, each with its
/// ID and about how many US dollars it is, as Prices by Country's price
/// popover lists them.
struct GetPricePointsTool: MCPTool {
    /// Points listed on each side of the price.
    static let pointsPerSide = 6
    /// Territories one call reads.
    static let territoryLimit = 40
    /// Points one territory lists between min and max.
    static let rangeLimit = 60

    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The product's Apple ID, product ID or name, from get_prices."),
        "territory": MCPToolDefinition.string("A territory code such as BRA or BR, or its name."),
        "territories": [
            "type": ["array", "string"],
            "items": ["type": "string"],
            "description": .string("""
            Several territories instead of territory (at most \(territoryLimit)): codes, a region, "currency:EUR", \
            "suggested", "setByYou" or "automatic", as in propose_prices.
            """),
        ],
        "near": ["type": "number", "description": "A price in the territory's currency to list points around. Defaults to today's price."],
        "nearUsd": ["type": "number", "description": "A US dollar amount to list points around in each territory, instead of near."],
        "min": ["type": "number", "description": "With max: every point from this price, in the territory's currency."],
        "max": ["type": "number", "description": .string("With min: every point up to this price (at most \(rangeLimit) points).")],
    ]

    let definition = MCPToolDefinition(
        name: "get_price_points",
        title: "Get price points",
        description: """
        Lists Apple's price points for one product in one territory (or several with territories) around today's \
        price, around near (in the territory's currency) or nearUsd (US dollars), or every point between min and \
        max: each point's customer price, proceeds (at the commission set in Atlas, after tax), pricePointId and \
        usd (about that many US dollars, from approximate rates). Marks the current point, Apple's automatic one \
        and the open suggestion. Only these prices can be proposed with propose_prices (price or pricePointId). A \
        subscription without a price in the United States yet lists its US points only (current is null): its US \
        price sets its starting price.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId"])
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let product = try catalog.requireProduct(arguments.string("productId"))
        let window = try MCPPricePointWindow(arguments)
        let selection = try MCPCountrySelection.parse(arguments)
        let code = try selection == nil ? arguments.string("territory") : nil
        guard var sheet = try await catalog.sheetIfPriced(for: product) else {
            let wanted = code ?? selection?.items.compactMap { if case let .territory(text) = $0 { text } else { nil } }.first ?? ""
            return try await Self.startingPoints(catalog: catalog, product: product, territory: wanted, window: window)
        }
        let countries = sheet.countryRows()
        let rows: [CountryPriceRow]
        if let code {
            guard let territory = sheet.territory(matching: code), let row = countries.first(where: { $0.id == territory.id }) else {
                throw MCPToolError.notFound(MCPPriceProposal.unknownTerritoryMessage(code, product: product))
            }
            rows = [row]
        } else {
            let resolution = selection?.resolve(in: countries)
            rows = resolution?.rows ?? []
            guard !rows.isEmpty else {
                let unknown = resolution?.unknown.first ?? ""
                throw MCPToolError.notFound(MCPPriceProposal.unknownTerritoryMessage(unknown, product: product))
            }
            guard rows.count <= Self.territoryLimit else {
                throw MCPToolError.invalidArgument(
                    name: "territories",
                    expected: String(localized: "at most \(Self.territoryLimit) territories; this selection has \(rows.count)")
                )
            }
        }
        try await sheet.loadExactLadders(for: rows.map(\.id))
        let entries = rows.map { Self.entry(for: $0, sheet: sheet, window: window) }
        guard code == nil else {
            return .read(entries[0], target: sheet.target(rows[0].territory.name))
        }
        return .read(["territories": .array(entries)], target: sheet.target)
    }

    /// One territory's points, with what marks them.
    private static func entry(for row: CountryPriceRow, sheet: MCPPriceSheet, window: MCPPricePointWindow) -> JSONValue {
        let ladder = sheet.ladder(for: row.territory)
        let current = row.current.customerPrice
        let points = window.points(in: ladder, current: current, currency: row.territory.currencyCode)
        var result: [String: JSONValue] = [
            "territory": .string(row.territory.id),
            "name": .string(row.territory.name),
            "currency": .string(row.territory.currencyCode),
            "current": MCPPriceValue.json(current),
            "setBy": .string(row.source.rawValue),
            "points": .array(points.map { point in
                var entry = pointJSON(point, currency: row.territory.currencyCode)
                if !PricingRow.differs(point.customerPrice, current) { entry["current"] = true }
                if !row.isBase, !PricingRow.differs(point.customerPrice, row.automatic.customerPrice) { entry["automatic"] = true }
                if let suggestion = row.suggestion, !PricingRow.differs(point.customerPrice, suggestion.customerPrice) { entry["suggested"] = true }
                return .object(entry)
            }),
        ]
        if !row.isBase { result["automaticPrice"] = MCPPriceValue.json(row.automatic.customerPrice) }
        if let suggestion = row.suggestion { result["suggested"] = MCPPriceValue.json(suggestion.customerPrice) }
        if let near = window.near { result["near"] = MCPPriceValue.json(near) }
        return .object(result)
    }

    /// A point's price, proceeds, ID and dollars.
    static func pointJSON(_ point: PricePoint, currency: String) -> [String: JSONValue] {
        var entry: [String: JSONValue] = [
            "price": MCPPriceValue.json(point.customerPrice),
            "proceeds": MCPPriceValue.json(point.proceeds.rounded(scale: 2)),
        ]
        if let id = point.appStoreConnectID { entry["pricePointId"] = .string(id) }
        if let usd = ExchangeRates.approximate.dollars(point.customerPrice, currency: currency) {
            entry["usd"] = MCPPriceValue.json(usd.rounded(scale: 2))
        }
        return entry
    }

    /// A subscription without a US price: Apple's US points around `near`
    /// (the lowest ones without it), to propose as its starting price.
    private static func startingPoints(
        catalog: MCPPriceCatalog,
        product: PricingProduct,
        territory code: String,
        window: MCPPricePointWindow
    ) async throws -> MCPToolOutcome {
        guard MCPStartingPriceProposer.isUnitedStates(code), let territory = MCPStartingPriceProposer.territory else {
            throw MCPToolError.unavailable(catalog.noStartingPriceMessage(product))
        }
        let ladder = try await MCPStartingPriceProposer.ladder(catalog: catalog, product: product)
        var result: [String: JSONValue] = [
            "territory": .string(territory.id),
            "name": .string(territory.name),
            "currency": .string(territory.currencyCode),
            "current": .null,
            "note": .string(String(localized: """
            No price in the United States yet. Propose one of these with propose_prices to set its starting price; \
            Apple equalizes it in every other country or region.
            """)),
            "points": .array(window.points(in: ladder, current: 0, currency: territory.currencyCode).map { point in
                .object(pointJSON(point, currency: territory.currencyCode))
            }),
        ]
        if let near = window.near { result["near"] = MCPPriceValue.json(near) }
        return .read(.object(result), target: "\(catalog.app.name) · \(product.name) · \(territory.name)")
    }

    /// Up to `pointsPerSide` points below the price and as many from it up.
    static func points(in ladder: PricePointLadder, around price: Decimal) -> [PricePoint] {
        let index = ladder.points.firstIndex { $0.customerPrice >= price } ?? ladder.points.count
        let lower = max(0, index - pointsPerSide)
        let upper = min(ladder.points.count, index + pointsPerSide)
        return Array(ladder.points[lower..<upper])
    }
}
