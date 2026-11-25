//
//  PriceChangeHistoryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Price changes pushed and read, their 28-day windows and HowSure's prior
/// changes.
@Suite("Price change history")
struct PriceChangeHistoryTests {
    private typealias Data = PricingSalesTestData

    private static let pushDate = PricingSampleData.date("2026-10-26")

    private func brazil() throws -> Territory {
        try #require(TerritoryCatalog.standard.territory(alpha3: "BRA"))
    }

    private func push(schedule: PriceSchedule = .immediate) throws -> PushRecord {
        var factory = PriceChangeFactory(appID: Data.appID, product: Data.annual)
        factory.schedule = schedule
        let change = try factory.change(
            for: brazil(),
            from: PricePoint(customerPrice: PricingFixtures.money("219.9"), proceeds: 150, appStoreConnectID: "old"),
            to: PricePoint(customerPrice: PricingFixtures.money("109.9"), proceeds: 75, appStoreConnectID: "new"),
            source: .suggestion,
            at: Self.pushDate
        )
        return PushRecord(date: Self.pushDate, appID: Data.appID, appName: "Lumen", title: "Prices", pushed: [change])
    }

    private func record(_ back: Int, territory: String = "BRA", origin: PriceHistoryOrigin = .read) -> PriceChangeRecord {
        PriceChangeRecord(
            productID: Data.annual.id, territoryID: territory, date: Data.through.adding(-back).date, oldPrice: 10, newPrice: 8,
            currencyCode: "BRL", origin: origin, recordedOn: Data.through.adding(-back).date
        )
    }

    private func reading(_ price: Decimal, startDay: String? = nil) -> [String: PriceChangeReading] {
        ["BRA": PriceChangeReading(price: price, currencyCode: "BRL", startDate: startDay.flatMap { AnalyticsDay(iso: $0)?.date })]
    }

    // MARK: - Pushes

    @Test func aPushsPriceChangesBecomeRecords() throws {
        let push = try push()
        let records = PriceChangeHistory.records(in: push)
        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.productID == Data.annual.id)
        #expect(record.territoryID == "BRA")
        #expect(record.oldPrice == PricingFixtures.money("219.9"))
        #expect(record.newPrice == PricingFixtures.money("109.9"))
        #expect(record.currencyCode == "BRL")
        #expect(record.origin == .pushed)
        #expect(record.pushID == push.id)
        #expect(record.date == Self.pushDate)
    }

    @Test func aScheduledPushIsDatedByItsStartDay() throws {
        let records = try PriceChangeHistory.records(in: push(schedule: PriceSchedule(startDay: "2026-12-01")))
        #expect(records.first?.date == AnalyticsDay(iso: "2026-12-01")?.date)
    }

    @Test func changeIDsSplitIntoProductAndTerritory() {
        #expect(PriceChangeHistory.ids(of: "price.6450100002.BRA")?.productID == "6450100002")
        #expect(PriceChangeHistory.ids(of: "price.6450100002.BRA")?.territoryID == "BRA")
        #expect(PriceChangeHistory.ids(of: "newSubscription.app.lumen") == nil)
        #expect(PriceChangeHistory.ids(of: "price..BRA") == nil)
    }

    @Test func aPushIsRecordedOnce() throws {
        let records = try PriceChangeHistory.records(in: push())
        var history = PriceChangeHistory()
        history.add(pushed: records)
        history.add(pushed: records)
        #expect(history.records.count == 1)
    }

    // MARK: - Reads

    @Test func theFirstReadOnlyRemembersThePrice() {
        var history = PriceChangeHistory()
        history.noteRead(productID: Data.annual.id, prices: reading(10), at: Self.pushDate)
        #expect(history.records.isEmpty)
        #expect(history.known[Data.annual.id]?["BRA"]?.price == 10)
    }

    @Test func aDifferentPriceIsRecordedAsReadOnApplesStartDate() throws {
        var history = PriceChangeHistory()
        history.noteRead(productID: Data.annual.id, prices: reading(10), at: Self.pushDate)
        history.noteRead(productID: Data.annual.id, prices: reading(10), at: Self.pushDate.addingTimeInterval(3600))
        #expect(history.records.isEmpty)
        history.noteRead(productID: Data.annual.id, prices: reading(8, startDay: "2026-11-02"), at: PricingSampleData.date("2026-11-05"))
        let record = try #require(history.records.first)
        #expect(history.records.count == 1)
        #expect(record.origin == .read)
        #expect(record.oldPrice == 10)
        #expect(record.newPrice == 8)
        #expect(record.date == PricingSampleData.date("2026-11-02"))
    }

    @Test func aPushedChangeSeenOnTheNextReadIsntRecordedTwice() throws {
        var history = PriceChangeHistory()
        history.noteRead(productID: Data.annual.id, prices: reading(PricingFixtures.money("219.9")), at: Self.pushDate.addingTimeInterval(-60))
        try history.add(pushed: PriceChangeHistory.records(in: push()))
        history.noteRead(productID: Data.annual.id, prices: reading(PricingFixtures.money("109.9")), at: Self.pushDate.addingTimeInterval(60))
        #expect(history.records.count == 1)
        #expect(history.records.first?.origin == .pushed)
    }

    @Test func aScheduledPushBeforeItsDayChangesNothing() throws {
        var history = PriceChangeHistory()
        history.noteRead(productID: Data.annual.id, prices: reading(PricingFixtures.money("219.9")), at: Self.pushDate.addingTimeInterval(-60))
        try history.add(pushed: PriceChangeHistory.records(in: push(schedule: PriceSchedule(startDay: "2026-12-01"))))
        // Apple still shows the old price until Dec 1.
        history.noteRead(productID: Data.annual.id, prices: reading(PricingFixtures.money("219.9")), at: Self.pushDate.addingTimeInterval(60))
        #expect(history.records.count == 1)
    }

    // MARK: - Windows

    @Test func windowsAreKeptOnceTheReportsCoverBothSides() {
        var history = PriceChangeHistory(records: [record(40)])
        var asked: [ClosedRange<AnalyticsDay>] = []
        let signals: (ClosedRange<AnalyticsDay>) -> [String: SalesSignal] = { range in
            asked.append(range)
            return ["BRA": SalesSignal(pageViews: range.lowerBound == Data.through.adding(-68) ? 100 : 200, starts: 5)]
        }
        let id = Data.annual.id
        // 27 days after the change aren't all in yet.
        let early = history.snapshotWindows(productID: id, from: Data.through.adding(-100), through: Data.through.adding(-14), signals: signals)
        // The archive starts after the 28 days before.
        let late = history.snapshotWindows(productID: id, from: Data.through.adding(-60), through: Data.through, signals: signals)
        #expect(!early)
        #expect(!late)
        #expect(asked.isEmpty)
        let kept = history.snapshotWindows(productID: id, from: Data.through.adding(-68), through: Data.through.adding(-13), signals: signals)
        #expect(kept)
        #expect(history.records.first?.before?.pageViews == 100)
        #expect(history.records.first?.after?.pageViews == 200)
        #expect(asked == [Data.through.adding(-68)...Data.through.adding(-41), Data.through.adding(-40)...Data.through.adding(-13)])
        // Kept windows aren't read again.
        let again = history.snapshotWindows(productID: id, from: Data.through.adding(-100), through: Data.through, signals: signals)
        #expect(!again)
    }

    @Test func aTerritoryWithoutNumbersKeepsZeroWindows() {
        var history = PriceChangeHistory(records: [record(40, territory: "PRT")])
        history.snapshotWindows(productID: Data.annual.id, from: Data.through.adding(-100), through: Data.through) { _ in [:] }
        #expect(history.records.first?.before == .zero)
        #expect(history.records.first?.after == .zero)
    }

    @Test func priorChangesAreEachTerritorysNewestWithWindows() {
        var older = record(120)
        older.before = SalesSignal(pageViews: 1, starts: 1)
        older.after = SalesSignal(pageViews: 2, starts: 2)
        var newer = record(60)
        newer.before = SalesSignal(pageViews: 3, starts: 3)
        newer.after = SalesSignal(pageViews: 4, starts: 4)
        let unfinished = record(10)
        let history = PriceChangeHistory(records: [older, unfinished, newer])
        let prior = history.priorChanges(productID: Data.annual.id)
        #expect(prior.count == 1)
        #expect(prior["BRA"]?.after.starts == 4)
        #expect(prior["BRA"]?.previousPrice == 10)
        #expect(history.priorChanges(productID: "other").isEmpty)
    }
}
