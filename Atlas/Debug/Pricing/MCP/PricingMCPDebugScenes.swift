//
//  PricingMCPDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// What propose_prices leaves in Review & Push once an assistant sends its
/// evidence and how sure (`-AtlasDebugScene <id>`):
///
/// - `pr-prod-mcp-review`: Claude Code's Lumen Plus Annual prices for
///   Brazil (Not very sure: purchasing power and a few page views) and
///   India (Fairly sure: its own trials), each with "Based on: …" as its
///   details, as `MCPPriceEvidence.details` writes them.
enum PricingMCPDebugScenes {
    static let ids = ["pr-prod-mcp-review"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-mcp-review": AnyView(DebugMainScene(section: .subscriptionPricing, pendingChanges: changes, presentedSheet: .review))
        default: nil
        }
    }

    /// The two changes, as propose_prices queues them.
    @MainActor
    static var changes: [PendingChange] {
        let brazil = [
            MCPPriceEvidence(source: .priceIndex, detail: "Brazil feels like 2.0× the US price"),
            MCPPriceEvidence(source: .analytics, detail: "Brazil, 28 days: 31 page views"),
        ]
        let india = [
            MCPPriceEvidence(source: .sales, detail: "India, 90 days: 1,480 page views, 26 trials"),
            MCPPriceEvidence(source: .outside, detail: "Spotify India: ₹119 a month"),
        ]
        return [
            change("BRA", factor: Decimal(1) / 2, evidence: brazil, confidence: .notVerySure),
            change("IND", factor: Decimal(8) / 10, evidence: india, confidence: .fairlySure),
        ].compactMap(\.self)
    }

    /// The territory's price moved to the point nearest `factor` × today's.
    @MainActor
    private static func change(_ territoryID: String, factor: Decimal, evidence: [MCPPriceEvidence], confidence: HowSure) -> PendingChange? {
        let appID = DebugFixtures.AppID.lumen
        guard let product = DebugPricingCatalog.catalog(for: appID).product(id: DebugPricingCatalog.lumenAnnualID),
              let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
        else { return nil }
        let sheet = DebugPriceSheets.sheet(for: product, commission: .smallBusiness, canReadSales: true)
        guard let current = sheet.prices[territoryID]?.current,
              let point = sheet.ladders[territoryID]?.nearest(to: current.customerPrice * factor, rounding: .auto)
        else { return nil }
        var change = PriceChangeFactory(appID: appID, product: product)
            .change(for: territory, from: current, to: point, source: .assistant(client: "Claude Code"))
        change.layers = SuggestionLayers(details: MCPPriceEvidence.details(evidence), confidence: confidence)
        return change
    }
}
#endif
