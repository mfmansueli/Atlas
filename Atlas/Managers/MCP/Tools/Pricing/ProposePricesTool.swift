//
//  ProposePricesTool.swift
//  Atlas
//

import Foundation

/// `propose_prices`: queues an assistant's prices for one subscription or
/// in-app purchase (a price point, or back to Apple's automatic price), for
/// one country, a list, or every country a group names, checked like the
/// person's edits in Prices by Country, for review in Atlas.
struct ProposePricesTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withConfidence(Self.priceProperties
        .merging(MCPCountrySelection.properties) { first, _ in first }
        .merging(MCPPriceBulkAction.properties) { first, _ in first })

    private static let priceProperties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The subscription's or in-app purchase's Apple ID, product ID or name, from get_prices."),
        "territory": MCPToolDefinition.string("A territory code such as BRA or BR."),
        "price": ["type": "number", "description": "The new customer price in the territory's currency, e.g. 109.9."],
        "pricePointId": MCPToolDefinition.string("Apple's price point ID from get_price_points, instead of price."),
        "automatic": ["type": "boolean", "description": "true puts the territory back on Apple's automatic price, instead of a price."],
        "prices": [
            "type": "array",
            "description": "Several prices at once, instead of territory and price (or automatic).",
            "items": MCPToolDefinition.schema(
                [
                    "territory": MCPToolDefinition.string("A territory code."),
                    "price": ["type": "number", "description": "The new customer price."],
                    "pricePointId": MCPToolDefinition.string("Apple's price point ID, instead of price."),
                    "automatic": ["type": "boolean", "description": "true for Apple's automatic price, instead of a price."],
                ],
                required: ["territory"]
            ),
        ],
    ]

    let definition = MCPToolDefinition(
        name: "propose_prices",
        title: "Propose prices",
        description: """
        Proposes new prices for one subscription or in-app purchase, in any country or region: send territory \
        and price, several with prices: [{territory, price}], or many at once with territories (codes, "all", a \
        region, "currency:EUR", "suggested", "setByYou", "automatic"; except leaves some out) and one action: \
        price (one currency only), automatic: true (Set N to Automatic), acceptSuggestions: true (each country's \
        open suggestion) or withdraw: true (takes back your own proposals there). Prices are in the territory's \
        currency and must be one of Apple's price points (get_price_points; pricePointId works too); a price \
        between points is refused with the two nearest ones. Automatic: an in-app purchase's then follows the base \
        price with exchange rates and tax; a subscription's becomes the base price equalized. The base territory \
        has no automatic price. Each proposal is queued for the person to review in Atlas (status "queued"), one \
        Review & Push row per product; an in-app purchase's prices wait together as one change. Nothing reaches \
        App Store Connect until they push. Today's price is "unchanged" and withdraws your earlier proposal for \
        that territory. A subscription without a price in the United States yet takes only its US price, queued \
        as its starting price: Apple equalizes it in every other country or region. When prices start is \
        propose_price_schedule. Unknown territories or products and every price for an app set to Keep my prices \
        are refused (status "refused") with the reason.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let appID = try arguments.string("appId")
        let productID = try arguments.string("productId")
        if let bulk = try MCPPriceBulkRequest.parse(arguments) {
            return try await callBulk(bulk, appID: appID, productID: productID, arguments: arguments, in: context)
        }
        let (proposals, isBatch) = try MCPPriceProposal.list(from: arguments)
        let layers = try arguments.layers()
        let catalog = try await MCPPriceCatalog.load(app: appID, in: context.workspace)

        var run = MCPPriceRun()
        if let refusal = Self.refusal(for: productID, in: catalog) {
            for proposal in proposals {
                run.add(proposal, territoryID: nil, .refused(reason: refusal, nearest: []), target: "\(catalog.app.name) · \(productID) · \(proposal.territory)")
            }
            return run.outcome(isBatch: isBatch)
        }
        let product = try catalog.requireProduct(productID)
        guard var sheet = try await catalog.sheetIfPriced(for: product) else {
            if product.isInAppPurchase { throw MCPToolError.unavailable(catalog.noStartingPriceMessage(product)) }
            let starting = try await MCPStartingPriceProposer.load(catalog: catalog, product: product, source: context.source)
            for proposal in proposals {
                let outcome: MCPPriceProposer.Outcome = if proposal.isAutomatic {
                    .refused(reason: Self.startingAutomaticRefusal(product), nearest: [])
                } else if proposal.pricePointID != nil {
                    .refused(reason: Self.startingPointIDRefusal(product), nearest: [])
                } else {
                    starting.propose(proposal.price, territory: proposal.territory)
                }
                let territoryID = MCPStartingPriceProposer.isUnitedStates(proposal.territory) ? MCPStartingPriceProposer.territoryID : nil
                run.add(proposal, territoryID: territoryID, outcome, target: starting.target)
            }
            context.workspace.changes.attach(layers, to: run.queuedIDs)
            return run.outcome(isBatch: isBatch)
        }
        let territories = proposals.map { sheet.territory(matching: $0.territory) }
        let waiting = product.isInAppPurchase ? MCPInAppPurchasePriceProposer(sheet: sheet, source: context.source).queuedTerritoryIDs : []
        try await sheet.loadExactLadders(for: territories.compactMap { $0?.id } + waiting)
        let items = zip(proposals, territories).map { proposal, territory in MCPPriceRun.Item.prepare(proposal, territory: territory, sheet: sheet) }
        run.propose(items, sheet: sheet, source: context.source)
        context.workspace.changes.attach(layers, to: run.queuedIDs)
        return run.outcome(isBatch: isBatch)
    }

    // MARK: - Refusals

    /// A reason every proposal in the call is refused: Keep my prices or an
    /// unknown product.
    static func refusal(for productID: String, in catalog: MCPPriceCatalog) -> String? {
        if catalog.mode == .keepPrices { return catalog.keepPricesRefusal }
        guard catalog.product(matching: productID) != nil else { return catalog.unknownProductMessage(productID) }
        return nil
    }

    /// A subscription's first price is a price point; Apple equalizes the rest.
    private static func startingAutomaticRefusal(_ product: PricingProduct) -> String {
        String(localized: "\(product.name) has no price yet, so it has no automatic price either. Propose its US price first.")
    }

    /// A starting price is sent as its US price.
    private static func startingPointIDRefusal(_ product: PricingProduct) -> String {
        String(localized: "\(product.name) has no price yet. Send its US price as price, one of get_price_points’ US points.")
    }
}
