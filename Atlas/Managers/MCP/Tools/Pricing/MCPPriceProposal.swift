//
//  MCPPriceProposal.swift
//  Atlas
//

import Foundation

/// One price an assistant proposes for a territory, as `propose_prices`
/// takes it: a price point, or `automatic: true` for Apple's automatic
/// price (an in-app purchase's follows exchange rates and tax; a
/// subscription's is the base price equalized).
struct MCPPriceProposal: Hashable, Sendable {
    /// The territory as the assistant wrote it: a code or a name.
    var territory: String
    /// In the territory's currency; 0 when `isAutomatic`.
    var price: Decimal
    /// Back to Apple's automatic price instead of `price`.
    var isAutomatic = false
    /// Apple's price point ID from get_price_points, instead of `price`;
    /// the tool turns it into the point's price once the points are read.
    var pricePointID: String?

    init(territory: String, price: Decimal, isAutomatic: Bool = false, pricePointID: String? = nil) {
        self.territory = territory
        self.price = price
        self.isAutomatic = isAutomatic
        self.pricePointID = pricePointID
    }

    init(_ arguments: MCPToolArguments) throws {
        territory = try arguments.string("territory")
        if try arguments.optionalBool("automatic") == true {
            price = 0
            isAutomatic = true
            return
        }
        if let pointID = try arguments.optionalString("pricePointId"), !pointID.isEmpty {
            price = 0
            pricePointID = pointID
            return
        }
        guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
            throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "a positive price in the territory’s currency, e.g. 109.9"))
        }
        self.price = price
    }

    /// The proposals in a call: `prices: [{territory, price}]`, or one
    /// `territory` and `price`.
    static func list(from arguments: MCPToolArguments) throws -> (proposals: [MCPPriceProposal], isBatch: Bool) {
        guard let items = try arguments.optionalArray("prices") else { return try ([MCPPriceProposal(arguments)], false) }
        let expected = String(localized: "a non-empty list of {territory, price}, {territory, pricePointId} or {territory, automatic: true} objects")
        guard !items.isEmpty else { throw MCPToolError.invalidArgument(name: "prices", expected: expected) }
        let proposals = try items.map { item in
            guard let object = item.objectValue else { throw MCPToolError.invalidArgument(name: "prices", expected: expected) }
            return try MCPPriceProposal(MCPToolArguments(object))
        }
        return (proposals, true)
    }

    /// The proposal with its price point's price, or why the ID isn't one
    /// of the territory's points.
    func resolvingPoint(in ladder: PricePointLadder, territory: Territory) -> (proposal: MCPPriceProposal, refusal: String?) {
        guard let pricePointID else { return (self, nil) }
        guard let point = ladder.points.first(where: { $0.appStoreConnectID == pricePointID }) else {
            let reason = String(localized: "“\(pricePointID)” isn’t one of \(territory.name)’s price points. Use get_price_points for its IDs, or send price.")
            return (self, reason)
        }
        var resolved = self
        resolved.price = point.customerPrice
        resolved.pricePointID = nil
        return (resolved, nil)
    }

    /// Why a territory wasn't found.
    static func unknownTerritoryMessage(_ identifier: String, product: PricingProduct) -> String {
        String(localized: """
        “\(identifier)” isn’t a territory \(product.name) is sold in. Use App Store Connect’s three-letter code \
        (BRA) or the two-letter one (BR), as get_prices lists them.
        """)
    }
}
