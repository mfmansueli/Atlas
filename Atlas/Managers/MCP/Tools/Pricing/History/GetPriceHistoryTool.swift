//
//  GetPriceHistoryTool.swift
//  Atlas
//

import Foundation

/// `get_price_history`: a product's price changes, pushed from Atlas or
/// read from App Store Connect (`PriceChangeHistory`), newest first, each
/// with the 28 days of sales kept either side and Results' verdict.
/// Read-only.
struct GetPriceHistoryTool: MCPTool {
    static let defaultLimit = 50

    static let hint = """
    Each change: `territory`, `name`, `currency`, `date` (when the new price took effect), `old` → `new`, \
    `origin` (pushed from Atlas, or read: made in App Store Connect or on another Mac). `before` and `after` are \
    the 28 days either side (pageViews, downloads, starts, trialStarts, paidStarts, proceedsUSD), kept once Apple's \
    reports cover both. `verdict` is Results' word: better, aboutTheSame, worse or tooLittleData (under 28 days or \
    30 starts on a side), with `verdictTitle` as Atlas shows it; `resultsOn` is the day a recent change's result \
    arrives. A change with a clear result is what makes get_prices' howSure Sure there.
    """

    let definition = MCPToolDefinition(
        name: "get_price_history",
        title: "Get the price history",
        description: """
        Lists an app's price changes per subscription or in-app purchase, newest first: territory, date, old → new \
        price, whether Atlas pushed it or read it from App Store Connect, the 28 days of sales either side and \
        Results' verdict (better, about the same, worse, too few to tell). Use it before proposing a price where one \
        changed before; never quote a result marked tooLittleData. productId reads one product, territories (codes) \
        only those countries; limit is \(defaultLimit) changes per product unless given; `hint` explains the fields. \
        Read-only.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "productId": MCPToolDefinition.string("A product's Apple ID, product ID or name. Leave it out for every product."),
                "territories": ["type": "array", "items": ["type": "string"], "description": "Only these countries: codes (BRA, BR) or names."],
                "limit": ["type": "integer", "description": .string("At most this many changes per product (default \(defaultLimit)).")],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let products = try arguments.optionalString("productId").map { try [catalog.requireProduct($0)] } ?? catalog.catalog.products
        let wanted = try (arguments.optionalStrings("territories") ?? []).map { try Self.territory($0) }
        let limit = try max(1, arguments.optionalInt("limit") ?? Self.defaultLimit)
        let now = Date.now
        var total = 0
        let entries: [JSONValue] = products.map { product in
            var records = context.workspace.services.pricing.priceHistory(for: product).sorted { $0.date > $1.date }
            if !wanted.isEmpty { records = records.filter { record in wanted.contains { $0.id == record.territoryID } } }
            total += records.count
            var entry: [String: JSONValue] = [
                "productId": .string(product.id),
                "name": .string(product.name),
                "count": .int(records.count),
                "changes": .array(records.prefix(limit).map { Self.json($0, now: now) }),
            ]
            if records.count > limit { entry["more"] = .int(records.count - limit) }
            return .object(entry)
        }
        var result: [String: JSONValue] = [
            "appId": .string(catalog.app.id),
            "app": .string(catalog.app.name),
            "hint": .string(Self.hint),
            "products": .array(entries),
        ]
        if total == 0 {
            result["note"] = "Atlas has seen no price change for these products yet: it records what it pushes and what it reads."
        }
        return .read(.object(result), target: String(localized: "\(catalog.app.name) · Price history", comment: "kind:other"))
    }

    /// One change, its windows and verdict.
    static func json(_ record: PriceChangeRecord, now: Date) -> JSONValue {
        let territory = TerritoryCatalog.standard.territory(alpha3: record.territoryID)
        var object: [String: JSONValue] = [
            "territory": .string(record.territoryID),
            "currency": .string(record.currencyCode),
            "date": .string(MCPPriceTrustJSON.day(record.date)),
            "old": MCPPriceValue.json(record.oldPrice),
            "new": MCPPriceValue.json(record.newPrice),
            "origin": .string(record.origin.rawValue),
        ]
        if let territory { object["name"] = .string(territory.name) }
        let verdict: ResultVerdict
        if let before = record.before, let after = record.after {
            object["before"] = MCPPriceTrustJSON.signal(before)
            object["after"] = MCPPriceTrustJSON.signal(after)
            verdict = ResultsEvaluator.verdict(before: SalesWindow(signal: before), after: SalesWindow(signal: after))
        } else {
            verdict = .tooLittleData
        }
        if case let .tooEarly(_, arrivesOn) = ResultsEvaluator.availability(changedOn: record.date, now: now) {
            object["resultsOn"] = .string(MCPPriceTrustJSON.day(arrivesOn))
        }
        object["verdict"] = .string(verdict.rawValue)
        object["verdictTitle"] = .string(verdict.title)
        return .object(object)
    }

    /// A territory by alpha-3, alpha-2 or name.
    private static func territory(_ text: String) throws -> Territory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalog = TerritoryCatalog.standard
        let match = catalog.territory(code: trimmed.uppercased())
            ?? catalog.territories.first { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        guard let match else {
            let expected = String(localized: "territory codes such as BRA or BR, or names", comment: "kind:other")
            throw MCPToolError.invalidArgument(name: "territories", expected: expected)
        }
        return match
    }
}
