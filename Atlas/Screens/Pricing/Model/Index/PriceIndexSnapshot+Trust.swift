//
//  PriceIndexSnapshot+Trust.swift
//  Atlas
//

import Foundation

extension PriceIndexSnapshot {
    /// An edition older than this is "Not very sure" (HowSure, Phase 5).
    static let staleAfterMonths = 18

    /// How far a territory's value in `source` can be trusted on `date`:
    /// missing without a value; approximate for the sample snapshot; stale
    /// once the edition is older than `staleAfterMonths`; otherwise the
    /// value's own method (exact, or fallback for an older year or another
    /// series).
    func trust(of source: PriceIndexSource, territoryID: String, asOf date: Date) -> PriceIndexTrust {
        guard let index = index(source), let provenance = index.levelProvenance(for: territoryID) else { return .missing }
        if isApproximate { return .approximate }
        if index.edition.isOlder(thanMonths: Self.staleAfterMonths, asOf: date) { return .stale }
        return provenance.isFallback ? .fallback : .exact
    }
}
