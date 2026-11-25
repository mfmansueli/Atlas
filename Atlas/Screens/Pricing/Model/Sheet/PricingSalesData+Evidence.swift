//
//  PricingSalesData+Evidence.swift
//  Atlas
//

import Foundation

/// The evidence behind each suggestion with pooling (Phase 3): build
/// `pooling(in:)` once per sheet, then `evidence(for:pooling:hasRealGrid:)`
/// per territory.
extension PricingSalesData {
    /// Conversion pooled country → region → world over the 90-day
    /// signals; empty when sales can't count.
    func pooling(in catalog: TerritoryCatalog = .standard) -> ConversionPooling {
        canRead ? ConversionPooling(signals: signals, catalog: catalog) : .empty
    }

    /// A territory's evidence: its windows, the base's, its earlier change,
    /// its pooled conversion and whether Apple's grid is real.
    func evidence(for territoryID: String, pooling: ConversionPooling, hasRealGrid: Bool) -> SalesEvidence {
        guard canRead else {
            return SalesEvidence(canReadSales: false, availability: availability, hasRealGrid: hasRealGrid)
        }
        return SalesEvidence(
            canReadSales: true,
            signal: signals[territoryID],
            baseSignal: signals[baseTerritoryID],
            priorChange: priorChanges[territoryID],
            availability: availability,
            recentSignal: recentSignals[territoryID],
            pooled: pooling.estimate(for: territoryID),
            basePooled: pooling.estimate(for: baseTerritoryID),
            usesTrials: pooling.usesTrials,
            hasRealGrid: hasRealGrid,
            readThrough: readThrough,
            priceTest: priceTests[territoryID]
        )
    }
}
