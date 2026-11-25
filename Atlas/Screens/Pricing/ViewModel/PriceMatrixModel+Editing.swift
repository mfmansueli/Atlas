//
//  PriceMatrixModel+Editing.swift
//  Atlas
//

import Foundation

/// Edits to one row or a few. Each loads Apple's price points
/// first if needed, snaps to them, and queues the result: hand edits as
/// `.you`, applied suggestions as `.suggestion`.
extension PriceMatrixModel {
    /// One price point up or down from the shown price.
    func step(_ id: PricingRow.ID, by steps: Int) async {
        guard !isReadOnly, await ensureLadders(for: [id]), let row = row(id: id),
              let point = ladder(for: row).step(from: row.shownPrice, by: steps, rounding: strategy.rounding) else { return }
        write([id: point], source: .you)
    }

    /// Sets a price picked from the nearby points or the source comparison.
    func setPrice(_ id: PricingRow.ID, to price: Decimal) async {
        guard !isReadOnly, await ensureLadders(for: [id]), let row = row(id: id) else { return }
        let ladder = ladder(for: row)
        guard let point = ladder.point(at: price) ?? ladder.nearest(to: price) else { return }
        write([id: point], source: .you)
    }

    /// Queues each territory's suggestion (or custom strategy price).
    func applySuggestion(to ids: [PricingRow.ID]) async {
        guard !isReadOnly, await ensureLadders(for: ids) else { return }
        var points: [String: PricePoint] = [:]
        for id in ids {
            guard let row = row(id: id), row.hasSuggestion else { continue }
            points[id] = row.target
        }
        write(points, source: .suggestion)
    }
}
