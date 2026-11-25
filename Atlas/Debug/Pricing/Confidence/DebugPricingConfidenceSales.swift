//
//  DebugPricingConfidenceSales.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Sample sales for HowSure's DEBUG scenes (`PricingConfidenceDebugScenes`),
/// on Lumen Plus Annual's sample prices. Kept apart from Results' fixture.
/// Every number is made up.
@MainActor
enum DebugPricingConfidenceSales {
    enum Scenario: String, CaseIterable, Sendable {
        /// Alba, Nov 2026: 79 page views in 90 days and no sales yet.
        case noSales
        /// Europe has the traffic; Portugal and France borrow its sales.
        case thin
        /// Most suggested countries have 300 page views and 10 trials of their own.
        case fairly
        /// Earlier changes in Brazil, India, Indonesia, Mexico and Türkiye
        /// with a clear lift: they carry most of the traffic.
        case sure
        /// Every price already at the suggestion: no banner, the summary line.
        case matched
    }

    /// The last day the sample reports cover.
    static let readThrough = PricingSampleData.date("2026-11-22")
    /// The sample's earlier changes, in May: "Your May change: …".
    static let changeDate = PricingSampleData.date("2026-05-12")

    /// The sample snapshot taken as published and recent, so HowSure can go
    /// past Not very sure in DEBUG (the bundled values are approximate).
    static let snapshot: PriceIndexSnapshot = {
        var snapshot = PricingSampleData.shared.snapshot
        snapshot.isApproximate = false
        for (source, index) in snapshot.indices {
            var recent = index
            recent.edition.date = PricingSampleData.date("2026-07-01")
            snapshot.indices[source] = recent
        }
        return snapshot
    }()

    /// The sheet with the scenario's sales (and, for `matched`, every price
    /// moved to its suggestion).
    static func sheet(_ sheet: ProductPriceSheet, scenario: Scenario, commission: Commission) -> ProductPriceSheet {
        var sheet = sheet
        sheet.sales = sales(scenario, sheet: sheet)
        if scenario == .matched { sheet = matching(sheet, commission: commission) }
        return sheet
    }

    static func sales(_ scenario: Scenario, sheet: ProductPriceSheet) -> PricingSalesData {
        switch scenario {
        case .noSales, .matched:
            return data(.noSalesYet, albaLike)
        case .thin:
            return data(.available, thin)
        case .fairly:
            return data(.available, fairly)
        case .sure:
            var sales = data(.available, sure)
            for (territoryID, change) in sureChanges {
                guard let current = sheet.prices[territoryID]?.current.customerPrice else { continue }
                sales.priorChanges[territoryID] = PriorPriceChange(
                    date: changeDate, previousPrice: current * 5 / 4, before: change.before, after: change.after
                )
            }
            return sales
        }
    }

    // MARK: - Private

    private typealias Row = (pageViews: Int, trials: Int, paid: Int)

    private static func data(_ availability: PricingSalesData.Availability, _ rows: [String: Row]) -> PricingSalesData {
        var signals: [String: SalesSignal] = [:]
        var recent: [String: SalesSignal] = [:]
        for (territoryID, row) in rows {
            let starts = row.trials + row.paid / 4
            signals[territoryID] = SalesSignal(
                pageViews: row.pageViews, starts: starts, downloads: row.pageViews / 3, trialStarts: row.trials, paidStarts: row.paid,
                proceeds: Decimal(row.paid) * 18
            )
            // About a third of the 90 days, as the last 28 days.
            recent[territoryID] = SalesSignal(
                pageViews: row.pageViews * 3 / 10, starts: starts * 3 / 10, downloads: row.pageViews / 10,
                trialStarts: row.trials * 3 / 10, paidStarts: row.paid * 3 / 10, proceeds: Decimal(row.paid * 3 / 10) * 18
            )
        }
        return PricingSalesData(
            availability: availability, signals: signals, recentSignals: recent, baseTerritoryID: "USA", readThrough: readThrough
        )
    }

    /// 79 page views in 90 days, no starts.
    private static let albaLike: [String: Row] = [
        "USA": (22, 0, 0), "BRA": (9, 0, 0), "DEU": (8, 0, 0), "GBR": (7, 0, 0), "IND": (6, 0, 0), "FRA": (5, 0, 0),
        "JPN": (5, 0, 0), "MEX": (4, 0, 0), "ESP": (4, 0, 0), "ITA": (3, 0, 0), "CAN": (3, 0, 0), "TUR": (3, 0, 0),
    ]

    /// Europe: 2,770 page views and 43 trials; Portugal has 40 of its own.
    private static let thin: [String: Row] = [
        "USA": (1500, 30, 14), "DEU": (900, 14, 6), "GBR": (800, 12, 5), "FRA": (500, 8, 3), "ESP": (200, 3, 1),
        "ITA": (150, 2, 1), "NLD": (120, 2, 1), "POL": (60, 1, 0), "PRT": (40, 1, 0), "BRA": (120, 1, 0), "MEX": (80, 1, 0),
        "JPN": (100, 2, 1), "IND": (90, 0, 0),
    ]

    private static let fairly: [String: Row] = [
        "USA": (6000, 160, 70), "BRA": (2400, 40, 15), "IND": (3100, 22, 6), "DEU": (2300, 60, 26), "GBR": (1900, 55, 24),
        "FRA": (1400, 30, 12), "MEX": (1050, 14, 5), "JPN": (950, 25, 11), "IDN": (800, 11, 3), "TUR": (600, 10, 3),
        "ESP": (850, 18, 7), "ITA": (700, 12, 5), "CAN": (1300, 38, 17), "AUS": (900, 30, 13), "KOR": (450, 10, 4),
        "POL": (400, 10, 3), "NLD": (450, 14, 6), "ARG": (550, 4, 1), "COL": (320, 3, 1), "PHL": (350, 4, 1),
    ]

    private static let sure: [String: Row] = [
        "USA": (6000, 160, 70), "BRA": (2400, 60, 22), "IND": (3100, 48, 14), "IDN": (800, 18, 5), "MEX": (1050, 30, 11),
        "TUR": (600, 20, 6), "DEU": (320, 11, 5), "FRA": (200, 5, 2), "ESP": (150, 3, 1), "JPN": (300, 9, 4),
        "ARG": (250, 3, 1), "COL": (150, 2, 0),
    ]

    /// The 28 days either side of each May change: a clear lift in each.
    private static let sureChanges: [String: (before: SalesSignal, after: SalesSignal)] = [
        "BRA": (SalesSignal(pageViews: 2000, starts: 41), SalesSignal(pageViews: 2100, starts: 70)),
        "IND": (SalesSignal(pageViews: 2500, starts: 32), SalesSignal(pageViews: 2600, starts: 66)),
        "IDN": (SalesSignal(pageViews: 1500, starts: 30), SalesSignal(pageViews: 1550, starts: 52)),
        "MEX": (SalesSignal(pageViews: 1200, starts: 31), SalesSignal(pageViews: 1250, starts: 50)),
        "TUR": (SalesSignal(pageViews: 900, starts: 30), SalesSignal(pageViews: 950, starts: 52)),
    ]

    /// Every price where the built-in suggestion would put it, so none is suggested.
    private static func matching(_ sheet: ProductPriceSheet, commission: Commission) -> ProductPriceSheet {
        var sheet = sheet
        let calculator = PriceCalculator(catalog: .standard, snapshot: snapshot, commission: commission)
        let recommender = PriceRecommender(calculator: calculator, baseTerritoryID: sheet.baseTerritoryID)
        for (territoryID, price) in sheet.prices where territoryID != sheet.baseTerritoryID {
            guard let territory = TerritoryCatalog.standard.territory(alpha3: territoryID) else { continue }
            let input = PriceCalculationInput(
                territory: territory,
                basePrice: sheet.basePrice,
                equalizedPrice: price.equalized.customerPrice,
                ladder: sheet.ladder(for: territory, commission: commission),
                currentPrice: price.current.customerPrice,
                equalizationMultiplier: price.equalizationMultiplier
            )
            sheet.prices[territoryID]?.current = recommender.recommend(input, evidence: .unavailable).price
        }
        return sheet
    }
}
#endif
