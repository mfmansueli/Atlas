//
//  PriceResultsChangesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which change Results compares: the last push, or a newer change read
/// from App Store Connect.
@Suite("Price results changes")
struct PriceResultsChangesTests {
    private typealias Data = PricingSalesTestData

    private static let pushDate = PricingSampleData.date("2026-10-26")

    private func push(on date: Date = pushDate) throws -> PushRecord {
        let territory = try #require(TerritoryCatalog.standard.territory(alpha3: "BRA"))
        let change = PriceChangeFactory(appID: Data.appID, product: Data.annual).change(
            for: territory,
            from: PricePoint(customerPrice: PricingFixtures.money("219.9"), proceeds: 150, appStoreConnectID: "old"),
            to: PricePoint(customerPrice: PricingFixtures.money("109.9"), proceeds: 75, appStoreConnectID: "new"),
            source: .suggestion,
            at: date
        )
        return PushRecord(date: date, appID: Data.appID, appName: "Lumen", title: "Prices", pushed: [change])
    }

    private func read(_ territoryID: String, on day: String) -> PriceChangeRecord {
        PriceChangeRecord(
            productID: Data.annual.id, territoryID: territoryID, date: PricingSampleData.date(day), oldPrice: 10, newPrice: 8,
            currencyCode: "EUR", origin: .read, recordedOn: PricingSampleData.date(day)
        )
    }

    @Test func nothingChangedIsNil() {
        #expect(PriceResultsChanges.latest(product: Data.annual, appID: Data.appID, records: [], history: []) == nil)
    }

    @Test func theLastPushKeepsItsChangesForRestore() throws {
        let latest = try #require(PriceResultsChanges.latest(
            product: Data.annual, appID: Data.appID, records: [push()], history: [read("DEU", on: "2026-09-01")]
        ))
        #expect(latest.date == Self.pushDate)
        #expect(Array(latest.entries.keys) == ["BRA"])
        #expect(latest.entries["BRA"]?.pushed != nil)
        #expect(latest.entries["BRA"]?.newPrice == PricingFixtures.money("109.9"))
    }

    @Test func aScheduledPushIsDatedByTheHistory() throws {
        let push = try push()
        let scheduled = PriceChangeHistory.records(in: push).map { record in
            var record = record
            record.date = PricingSampleData.date("2026-11-02")
            return record
        }
        let latest = try #require(PriceResultsChanges.latest(product: Data.annual, appID: Data.appID, records: [push], history: scheduled))
        #expect(latest.date == PricingSampleData.date("2026-11-02"))
    }

    @Test func aNewerChangeReadFromAppStoreConnectWins() throws {
        let latest = try #require(PriceResultsChanges.latest(
            product: Data.annual, appID: Data.appID, records: [push()],
            history: [read("DEU", on: "2026-11-10"), read("FRA", on: "2026-11-10"), read("ITA", on: "2026-11-01")]
        ))
        #expect(latest.date == PricingSampleData.date("2026-11-10"))
        #expect(Set(latest.entries.keys) == ["DEU", "FRA"])
        #expect(latest.entries.values.allSatisfy { $0.pushed == nil })
    }

    @Test func anotherAppsOrProductsChangesDontCount() throws {
        var other = try push()
        other.appID = "another"
        var otherProduct = read("DEU", on: "2026-11-10")
        otherProduct.productID = Data.monthly.id
        #expect(PriceResultsChanges.latest(product: Data.annual, appID: Data.appID, records: [other], history: [otherProduct]) == nil)
    }
}
