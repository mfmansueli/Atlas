//
//  SalesEvidence.swift
//  Atlas
//

import Foundation

/// What a suggestion can know beyond purchasing power.
struct SalesEvidence: Hashable, Sendable {
    /// False when sales can't count (the key's role, Settings, not read):
    /// every suggestion is then Not very sure, on purchasing power alone.
    var canReadSales: Bool
    /// Why sales count or not, for the per-state lines.
    var availability: PricingSalesData.Availability
    /// This territory's last 90 days; nil when it sold too little to report.
    var signal: SalesSignal?
    /// Its last 28 days, for the evidence lines.
    var recentSignal: SalesSignal?
    /// The base territory's last 90 days, the conversion reference.
    var baseSignal: SalesSignal?
    var priorChange: PriorPriceChange?
    /// The territory's conversion pooled with its region's
    /// (`ConversionPooling`); nil without pooling.
    var pooled: PooledConversion?
    /// The base territory's, pooled the same way.
    var basePooled: PooledConversion?
    /// HowSure counts trial starts (the product has trials), else every start.
    var usesTrials: Bool
    /// Apple's own price points are here for the territory.
    var hasRealGrid: Bool
    /// The last day the reports cover.
    var readThrough: Date?
    /// A finished price test in the territory's region.
    var priceTest: PriceTestEvidence?

    init(
        canReadSales: Bool,
        signal: SalesSignal? = nil,
        baseSignal: SalesSignal? = nil,
        priorChange: PriorPriceChange? = nil,
        availability: PricingSalesData.Availability? = nil,
        recentSignal: SalesSignal? = nil,
        pooled: PooledConversion? = nil,
        basePooled: PooledConversion? = nil,
        usesTrials: Bool = false,
        hasRealGrid: Bool = false,
        readThrough: Date? = nil,
        priceTest: PriceTestEvidence? = nil
    ) {
        self.canReadSales = canReadSales
        self.availability = availability ?? (canReadSales ? .available : .roleCannotRead)
        self.signal = signal
        self.recentSignal = recentSignal
        self.baseSignal = baseSignal
        self.priorChange = priorChange
        self.pooled = pooled
        self.basePooled = basePooled
        self.usesTrials = usesTrials
        self.hasRealGrid = hasRealGrid
        self.readThrough = readThrough
        self.priceTest = priceTest
    }

    /// A key that can't read sales.
    static let unavailable = SalesEvidence(canReadSales: false)
}
