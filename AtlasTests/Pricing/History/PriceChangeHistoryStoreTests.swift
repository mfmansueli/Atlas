//
//  PriceChangeHistoryStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Each app's price history, in memory or as JSON in a folder.
@MainActor
@Suite("Price change history store")
struct PriceChangeHistoryStoreTests {
    private typealias Data = PricingSalesTestData

    private func sampleRecord() -> PriceChangeRecord {
        PriceChangeRecord(
            productID: Data.annual.id, territoryID: "BRA", date: Data.through.date, oldPrice: PricingFixtures.money("219.9"),
            newPrice: PricingFixtures.money("109.9"), currencyCode: "BRL", origin: .read, recordedOn: Data.through.date,
            before: SalesSignal(pageViews: 100, starts: 31), after: SalesSignal(pageViews: 120, starts: 40, trialStarts: 30, proceeds: 12.5)
        )
    }

    @Test func keepsEachAppApartInMemory() {
        let store = PriceChangeHistoryStore()
        store.update(Data.appID) { $0.records.append(sampleRecord()) }
        #expect(store.history(for: Data.appID).records.count == 1)
        #expect(store.history(for: "another").records.isEmpty)
    }

    @Test func savesAndReadsBackTheFile() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "price-history-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let record = sampleRecord()
        PriceChangeHistoryStore(directory: directory).update(Data.appID) { $0.records.append(record) }
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "price-history-\(Data.appID).json").path))
        let reread = PriceChangeHistoryStore(directory: directory).history(for: Data.appID)
        #expect(reread.records == [record])
    }

    @Test func recordsAPushsPriceChanges() throws {
        let territory = try #require(TerritoryCatalog.standard.territory(alpha3: "BRA"))
        let change = PriceChangeFactory(appID: Data.appID, product: Data.annual).change(
            for: territory,
            from: PricePoint(customerPrice: PricingFixtures.money("219.9"), proceeds: 150, appStoreConnectID: "old"),
            to: PricePoint(customerPrice: PricingFixtures.money("109.9"), proceeds: 75, appStoreConnectID: "new"),
            source: .suggestion
        )
        let store = PriceChangeHistoryStore()
        store.record(push: PushRecord(date: .now, appID: Data.appID, appName: "Lumen", title: "Prices", pushed: [change]))
        #expect(store.history(for: Data.appID).records.map(\.territoryID) == ["BRA"])
    }
}
