//
//  LocalDataTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → Privacy & Data (board 48): the activity, what can be made
/// again, and that tests and DEBUG scenes never delete anything.
@MainActor
@Suite("Privacy and data")
struct LocalDataTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LocalDataTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10000).write(to: url.appending(path: "render.png"))
        return url
    }

    @Test func theCachesSize() async throws {
        let caches = try folder()
        defer { try? FileManager.default.removeItem(at: caches) }
        let store = LocalDataStore(cachesDirectory: caches, supportDirectory: caches, isLive: false)
        #expect(await store.cacheSize() >= 10000)
    }

    @Test func clearingDeletesOnlyWhenLive() throws {
        let caches = try folder()
        defer { try? FileManager.default.removeItem(at: caches) }
        let test = LocalDataStore(cachesDirectory: caches, supportDirectory: caches, isLive: false)
        test.clearCaches()
        #expect(test.clearedCaches == 1)
        #expect(FileManager.default.fileExists(atPath: caches.path()))
        LocalDataStore(cachesDirectory: caches, supportDirectory: caches, isLive: true).clearCaches()
        #expect(!FileManager.default.fileExists(atPath: caches.path()))
    }

    /// The tests' host is never live: Remove All Keys and Data… only counts.
    @Test func theTestsHostNeverRemovesAnything() {
        #expect(!LocalDataStore.defaultIsLive)
        #expect(!LocalDataStore.shared.isLive)
        #expect(LocalDataStore.supportItems.contains("Atlas"))
        #expect(!LocalDataStore.supportItems.contains(""))
    }

    @Test func activityIsPushesAndCallsNewestFirst() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let push = PushRecord(date: now.addingTimeInterval(-60), appID: "app", appName: "Lumen", title: "Store Page", pushed: [])
        let call = MCPLogEntry(
            date: now, client: "Claude Code", tool: "propose_prices", target: "Lumen", outcome: .refused, reason: "Keep my prices"
        )
        let lines = ActivityLine.lines(pushes: [push], calls: [call])
        #expect(lines.map(\.kind) == [.assistant, .push])
        #expect(lines.first?.title == "Claude Code: propose_prices")
        #expect(lines.first?.detail == "Refused · Lumen · Keep my prices")
        #expect(lines.last?.detail == "0 pushed")
        let exported = try JSONSerialization.jsonObject(with: ActivityLine.exportData(lines)) as? [[String: Any]]
        #expect(exported?.count == 2)
    }
}
