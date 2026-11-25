//
//  LivePricingCacheTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Apple's price point ladders kept per product, commission and territory:
/// what's fresh, what a push drops, what survives a relaunch, and one read
/// of a product at a time.
@MainActor
@Suite("Pricing · price point cache")
struct LivePricingCacheTests {
    private let start = Date(timeIntervalSince1970: 1_795_000_000)

    private func ladder(_ territoryID: String = "BRA", ids: Bool = true) -> PricePointLadder {
        PricePointLadder(territoryID: territoryID, currencyCode: "BRL", points: [
            PricePoint(customerPrice: PricingFixtures.money("9.90"), proceeds: PricingFixtures.money("7.15"), appStoreConnectID: ids ? "p-990" : nil),
            PricePoint(customerPrice: PricingFixtures.money("19.90"), proceeds: PricingFixtures.money("14.38"), appStoreConnectID: ids ? "p-1990" : nil),
        ])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "LivePricingCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func aStoredLadderIsAHit() async {
        let cache = LivePricingCache(directory: nil, now: { start })
        cache.store(["BRA": ladder()], for: "s1", commission: .smallBusiness)
        let found = await cache.ladders(for: "s1", commission: .smallBusiness, territoryIDs: ["BRA", "DEU"])
        #expect(Array(found.keys) == ["BRA"])
        #expect(found["BRA"]?.points.map(\.appStoreConnectID) == ["p-990", "p-1990"])
    }

    @Test func anotherCommissionOrProductIsAMiss() async {
        let cache = LivePricingCache(directory: nil, now: { start })
        cache.store(["BRA": ladder()], for: "s1", commission: .smallBusiness)
        #expect(await cache.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA"]).isEmpty)
        #expect(await cache.ladders(for: "s2", commission: .smallBusiness, territoryIDs: ["BRA"]).isEmpty)
    }

    @Test func anEmptyLadderIsNotKept() async {
        let cache = LivePricingCache(directory: nil, now: { start })
        cache.store(["BRA": PricePointLadder(territoryID: "BRA", currencyCode: "BRL", points: [])], for: "s1", commission: .standard)
        #expect(await cache.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA"]).isEmpty)
    }

    @Test func aLadderOlderThanSevenDaysIsAMiss() async {
        var now = start
        let cache = LivePricingCache(directory: nil, now: { now })
        cache.store(["BRA": ladder()], for: "s1", commission: .standard)
        now = start.addingTimeInterval(LivePricingCache.maxAge - 60)
        #expect(await cache.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA"]).count == 1)
        now = start.addingTimeInterval(LivePricingCache.maxAge + 60)
        #expect(await cache.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA"]).isEmpty)
    }

    @Test func aPushDropsOnlyWhatWasReadBeforeIt() async {
        var now = start
        let cache = LivePricingCache(directory: nil, now: { now })
        cache.store(["BRA": ladder()], for: "s1", commission: .standard)
        now = start.addingTimeInterval(3600)
        cache.store(["DEU": ladder("DEU")], for: "s1", commission: .standard)
        cache.store(["BRA": ladder()], for: "s2", commission: .standard)
        await cache.forget(productID: "s1", fetchedBefore: start.addingTimeInterval(60))
        let left = await cache.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA", "DEU"])
        #expect(Array(left.keys) == ["DEU"])
        // Another product keeps its ladders.
        #expect(await cache.ladders(for: "s2", commission: .standard, territoryIDs: ["BRA"]).count == 1)
    }

    @Test func laddersSurviveARelaunchOnDisk() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = LivePricingCache(directory: directory, now: { start })
        first.store(["BRA": ladder()], for: "s1", commission: .smallBusiness)
        await first.finishWriting()
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "ladders-s1.json").path()))

        let second = LivePricingCache(directory: directory, now: { start.addingTimeInterval(60) })
        let found = try #require(await second.ladders(for: "s1", commission: .smallBusiness, territoryIDs: ["BRA"])["BRA"])
        #expect(found.points == ladder().points)
        #expect(found.currencyCode == "BRL")
        #expect(second.fetchDate(productID: "s1", commission: .smallBusiness, territoryID: "BRA") == start)
    }

    @Test func aLadderReadFromDiskStillExpires() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = LivePricingCache(directory: directory, now: { start })
        first.store(["BRA": ladder()], for: "s1", commission: .standard)
        await first.finishWriting()
        let later = LivePricingCache(directory: directory, now: { start.addingTimeInterval(LivePricingCache.maxAge + 1) })
        #expect(await later.ladders(for: "s1", commission: .standard, territoryIDs: ["BRA"]).isEmpty)
    }

    @Test func forgettingEverythingRemovesTheFile() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LivePricingCache(directory: directory, now: { start })
        cache.store(["BRA": ladder()], for: "s1", commission: .standard)
        await cache.finishWriting()
        await cache.forget(productID: "s1", fetchedBefore: start.addingTimeInterval(1))
        await cache.finishWriting()
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "ladders-s1.json").path()))
    }

    @Test func oneProductIsReadOnceAtATime() async {
        let cache = LivePricingCache(directory: nil, now: { start })
        let overlap = Overlap()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask { await overlap.read(cache, productID: "s1") }
            }
        }
        #expect(overlap.mostAtOnce == 1)
        #expect(overlap.reads == 3)
        #expect(!cache.isReading("s1"))
    }

    @Test func differentProductsReadSideBySide() async {
        let cache = LivePricingCache(directory: nil, now: { start })
        let overlap = Overlap()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await overlap.read(cache, productID: "s1") }
            group.addTask { await overlap.read(cache, productID: "s2") }
        }
        #expect(overlap.mostAtOnce == 2)
    }

    /// Counts the reads running at once.
    @MainActor
    private final class Overlap {
        private var active = 0
        private(set) var mostAtOnce = 0
        private(set) var reads = 0

        func read(_ cache: LivePricingCache, productID: String) async {
            await cache.serialized(productID: productID) {
                active += 1
                reads += 1
                mostAtOnce = max(mostAtOnce, active)
                try? await Task.sleep(for: .milliseconds(20))
                active -= 1
            }
        }
    }
}
