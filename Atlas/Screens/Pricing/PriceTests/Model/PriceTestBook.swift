//
//  PriceTestBook.swift
//  Atlas
//

import Foundation

/// One app's price tests and the tests the assistant suggested, kept in
/// `Application Support/Atlas/Pricing/price-tests-<app>.json`.
struct PriceTestBook: Hashable, Codable, Sendable {
    var tests: [PriceTest] = []
    var suggestions: [PriceTestSuggestion] = []

    func test(id: PriceTest.ID) -> PriceTest? {
        tests.first { $0.id == id }
    }

    /// Keeps the 28 days before and during each of the product's finished
    /// tests once the reports run from the day before through its last day:
    /// the test's countries, and the comparison region's (the base country
    /// left out). True when one was kept.
    @discardableResult
    mutating func snapshotWindows(
        productID: String,
        from: AnalyticsDay,
        through: AnalyticsDay,
        baseTerritoryID: String,
        catalog: TerritoryCatalog = .standard,
        readOn: Date,
        signals: (ClosedRange<AnalyticsDay>) -> [String: SalesSignal]
    ) -> Bool {
        var changed = false
        for index in tests.indices where tests[index].productID == productID && tests[index].windows == nil {
            let test = tests[index]
            guard test.state == .running, let start = test.startedOn.map(AnalyticsDay.init) else { continue }
            let before = start.adding(-PriceTest.days)...start.adding(-1)
            let during = start...start.adding(PriceTest.days - 1)
            guard from <= before.lowerBound, through >= during.upperBound else { continue }
            let beforeSignals = signals(before)
            let duringSignals = signals(during)
            let tested = test.territoryIDs
            let control = test.control.map { region in
                Set(catalog.territories(in: region).map(\.id)).subtracting([baseTerritoryID])
            }
            func total(_ signals: [String: SalesSignal], _ ids: Set<String>) -> SalesSignal {
                ids.reduce(SalesSignal.zero) { $0 + (signals[$1] ?? .zero) }
            }
            tests[index].windows = PriceTestWindows(
                testBefore: total(beforeSignals, tested),
                testDuring: total(duringSignals, tested),
                controlBefore: control.map { total(beforeSignals, $0) },
                controlDuring: control.map { total(duringSignals, $0) },
                readOn: readOn
            )
            changed = true
        }
        return changed
    }

    mutating func replace(_ test: PriceTest) {
        if let index = tests.firstIndex(where: { $0.id == test.id }) {
            tests[index] = test
        } else {
            tests.append(test)
        }
    }
}
