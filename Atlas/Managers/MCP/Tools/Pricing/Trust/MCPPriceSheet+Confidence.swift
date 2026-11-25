//
//  MCPPriceSheet+Confidence.swift
//  Atlas
//

import Foundation

// How sure Atlas is of a price in each country (`PriceConfidenceRule`), as
// get_prices reports it and propose_prices caps an assistant's confidence
// with it: the suggestion's own how sure where Pricing made one, else the
// same rule over the product's sales, index and price grid, so in-app
// purchases, Keep my prices and the base territory have one too.
extension MCPPriceSheet {
    /// Conversion pooled country → region → world: build it once per call.
    var pooling: ConversionPooling {
        sheet.sales.pooling(in: territories)
    }

    /// The row's how sure: its suggestion's, else the rule's.
    func confidence(of row: PricingRow, pooling: ConversionPooling) -> PriceConfidence? {
        if let recommendation = row.recommendation, let level = recommendation.confidence, !recommendation.howSureReason.isEmpty {
            return PriceConfidence(level: level, reason: recommendation.howSureReason, borrowedFrom: recommendation.evidence?.borrowedFrom)
        }
        return confidence(in: row.territory, pooling: pooling)
    }

    /// What Atlas's own evidence supports in the territory, worked out as
    /// a suggestion's is; nil where the product has no price.
    func confidence(in territory: Territory, pooling: ConversionPooling) -> PriceConfidence? {
        guard let input = rowBuilder.input(for: territory) else { return nil }
        let evidence = sheet.sales.evidence(for: territory.id, pooling: pooling, hasRealGrid: sheet.hasRealGrid(territory.id))
        let strategy = PricingStrategy.recommended(baseTerritoryID: sheet.baseTerritoryID)
        let resolved = calculator.resolveFactor(for: territory, strategy: strategy)
        let recommender = PriceRecommender(calculator: calculator, baseTerritoryID: sheet.baseTerritoryID)
        return recommender.confidence(input, evidence: evidence, provenance: resolved.provenance)
    }
}
