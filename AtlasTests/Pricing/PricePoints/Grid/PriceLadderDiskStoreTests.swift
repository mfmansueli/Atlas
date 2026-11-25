//
//  PriceLadderDiskStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The ladders' file on this Mac: exact amounts, safe names, and nothing
/// read from a file of another version or product.
@Suite("Pricing · price point files")
struct PriceLadderDiskStoreTests {
    private func store() -> PriceLadderDiskStore {
        PriceLadderDiskStore(directory: FileManager.default.temporaryDirectory.appending(
            path: "PriceLadderDiskStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory
        ))
    }

    private let fetched = Date(timeIntervalSince1970: 1_795_000_000)

    @Test func amountsComeBackExactly() {
        let ladder = PricePointLadder(territoryID: "IDN", currencyCode: "IDR", points: [
            PricePoint(customerPrice: PricingFixtures.money("0.99"), proceeds: PricingFixtures.money("0.84"), appStoreConnectID: "a"),
            PricePoint(customerPrice: PricingFixtures.money("199000"), proceeds: PricingFixtures.money("152396.40")),
        ])
        let stored = StoredPriceLadders.ladder(ladder, fetchedAt: fetched)
        #expect(stored.points == [["0.99", "0.84", "a"], ["199000", "152396.4"]])
        let back = StoredPriceLadders.pricePointLadder(stored, territoryID: "IDN")
        #expect(back.points == ladder.points)
        #expect(back.points.last?.appStoreConnectID == nil)
    }

    @Test func aRoundTripKeepsEveryCommissionAndDate() throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let ladder = StoredPriceLadders.Ladder(fetchedAt: fetched, currencyCode: "BRL", points: [["9.90", "7.15", "p1"]])
        let saved = StoredPriceLadders(productID: "s1", ladders: ["smallBusiness": ["BRA": ladder], "standard": ["BRA": ladder]])
        store.write(saved)
        let read = try #require(store.read(productID: "s1"))
        #expect(read == saved)
    }

    @Test func aMissingFileOrAnotherProductReadsAsNothing() {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(store.read(productID: "s1") == nil)
        let saved = StoredPriceLadders(productID: "s1", ladders: ["standard": ["BRA": .init(fetchedAt: fetched, currencyCode: "BRL", points: [])]])
        store.write(saved)
        // Another product's file under this name isn't trusted.
        try? FileManager.default.copyItem(at: store.url(for: "s1"), to: store.url(for: "s2"))
        #expect(store.read(productID: "s2") == nil)
    }

    @Test func anotherVersionReadsAsNothing() {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var saved = StoredPriceLadders(productID: "s1", ladders: ["standard": ["BRA": .init(fetchedAt: fetched, currencyCode: "BRL", points: [])]])
        saved.version = StoredPriceLadders.currentVersion + 1
        store.write(saved)
        #expect(store.read(productID: "s1") == nil)
    }

    @Test func nothingLeftRemovesTheFile() {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        store.write(StoredPriceLadders(productID: "s1", ladders: ["standard": ["BRA": .init(fetchedAt: fetched, currencyCode: "BRL", points: [])]]))
        #expect(FileManager.default.fileExists(atPath: store.url(for: "s1").path()))
        store.write(StoredPriceLadders(productID: "s1"))
        #expect(!FileManager.default.fileExists(atPath: store.url(for: "s1").path()))
    }

    @Test func fileNamesAreSafe() {
        let store = PriceLadderDiskStore(directory: URL(filePath: "/tmp/ladders"))
        #expect(store.url(for: "6450100002").lastPathComponent == "ladders-6450100002.json")
        #expect(store.url(for: "../a/b").lastPathComponent == "ladders-___a_b.json")
    }
}
