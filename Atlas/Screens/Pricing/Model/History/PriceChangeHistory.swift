//
//  PriceChangeHistory.swift
//  Atlas
//

import Foundation

/// One app's price changes, pushed by Atlas or read from App Store Connect,
/// and the last price read per product and territory. Pure: the store
/// keeps it, tests build it.
struct PriceChangeHistory: Hashable, Codable, Sendable {
    /// Days on each side of a change.
    static let windowDays = 28

    var records: [PriceChangeRecord] = []
    /// Product ID → territory (alpha-3) → the last price read.
    var known: [String: [String: PriceChangeKnownPrice]] = [:]

    /// The product's changes, newest first.
    func records(productID: String) -> [PriceChangeRecord] {
        records.filter { $0.productID == productID }.sorted { $0.date > $1.date }
    }

    /// Each territory's newest change with both windows kept, for HowSure.
    func priorChanges(productID: String) -> [String: PriorPriceChange] {
        var result: [String: PriorPriceChange] = [:]
        for record in records(productID: productID) where result[record.territoryID] == nil {
            if let change = record.priorChange { result[record.territoryID] = change }
        }
        return result
    }

    // MARK: - Recording

    /// Pushed changes. A push's change for a territory is recorded once.
    mutating func add(pushed: [PriceChangeRecord]) {
        for record in pushed {
            let known = records.contains {
                $0.pushID != nil && $0.pushID == record.pushID && $0.productID == record.productID && $0.territoryID == record.territoryID
            }
            if !known { records.append(record) }
        }
    }

    /// Notes the prices a read found for `productID`. A territory whose
    /// price differs from the last one read changed in between: a push Atlas
    /// recorded since then with that price is the same change; anything else
    /// is recorded as read, dated by Apple's start date when there is one.
    /// The first read of a territory only remembers its price.
    mutating func noteRead(productID: String, prices: [String: PriceChangeReading], at now: Date) {
        var byTerritory = known[productID] ?? [:]
        for (territoryID, reading) in prices {
            let last = byTerritory[territoryID]
            byTerritory[territoryID] = PriceChangeKnownPrice(price: reading.price, currencyCode: reading.currencyCode, readOn: now)
            guard let last, last.currencyCode == reading.currencyCode, last.price != reading.price else { continue }
            let pushed = records.contains {
                $0.origin == .pushed && $0.productID == productID && $0.territoryID == territoryID
                    && $0.newPrice == reading.price && $0.recordedOn >= last.readOn
            }
            guard !pushed else { continue }
            records.append(PriceChangeRecord(
                productID: productID,
                territoryID: territoryID,
                date: reading.startDate ?? now,
                oldPrice: last.price,
                newPrice: reading.price,
                currencyCode: reading.currencyCode,
                origin: .read,
                recordedOn: now
            ))
        }
        known[productID] = byTerritory
    }

    /// Keeps the 28 days either side of `productID`'s changes once the
    /// reports cover both: `from` on or before the first day before,
    /// `through` on or after the last day after. `signals` reads a range
    /// per territory. Returns whether anything was kept.
    @discardableResult
    mutating func snapshotWindows(
        productID: String,
        from: AnalyticsDay,
        through: AnalyticsDay,
        signals: (ClosedRange<AnalyticsDay>) -> [String: SalesSignal]
    ) -> Bool {
        // Changes on the same day share their ranges: read each once.
        var read: [ClosedRange<AnalyticsDay>: [String: SalesSignal]] = [:]
        var changed = false
        for index in records.indices where records[index].productID == productID && !records[index].hasWindows {
            let record = records[index]
            guard from <= record.beforeRange.lowerBound, through >= record.afterRange.upperBound else { continue }
            for range in [record.beforeRange, record.afterRange] where read[range] == nil {
                read[range] = signals(range)
            }
            records[index].before = read[record.beforeRange]?[record.territoryID] ?? .zero
            records[index].after = read[record.afterRange]?[record.territoryID] ?? .zero
            changed = true
        }
        return changed
    }
}
