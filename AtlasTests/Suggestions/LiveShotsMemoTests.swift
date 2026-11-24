//
//  LiveShotsMemoTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The App Store preview's kept live screenshots: shown again at once,
/// read again only when over a minute old, one read shared, a failed read
/// leaving what was kept.
@MainActor
@Suite("LiveShotsMemo")
struct LiveShotsMemoTests {
    private let key = LiveShotsMemo.Key(appID: "1", localizations: [StoreLocaleCatalog.locale(code: "en-US")!: "loc-en"])

    @MainActor
    private final class Counter {
        var reads = 0
    }

    private func live(_ id: String) -> LiveScreenshots {
        LiveScreenshots(screenshotSets: [
            LiveScreenshotSet(id: id, locale: "en-US", displayType: .iPhone, screenshots: [LiveScreenshot(id: "\(id).0", fileName: "a.png")]),
        ])
    }

    @Test func nothingKeptNeedsARead() {
        let memo = LiveShotsMemo()
        #expect(memo.kept(key) == nil)
        #expect(memo.needsRead(key))
    }

    @Test func aReadIsKeptAndCurrentForAMinute() async {
        var clock = Date(timeIntervalSince1970: 0)
        let memo = LiveShotsMemo(freshFor: 60) { clock }
        let read = await memo.read(key) { live("a") }
        #expect(read == live("a"))
        #expect(memo.kept(key) == live("a"))
        #expect(!memo.needsRead(key))
        clock = clock.addingTimeInterval(61)
        #expect(memo.needsRead(key))
        #expect(memo.kept(key) == live("a"))
    }

    @Test func anotherVersionsLocalizationsReadTheirOwn() async throws {
        let memo = LiveShotsMemo()
        _ = await memo.read(key) { live("a") }
        var other = key
        other.localizations = try [#require(StoreLocaleCatalog.locale(code: "en-US")): "loc-en-2"]
        #expect(memo.kept(other) == nil)
        #expect(memo.needsRead(other))
    }

    @Test func aFailedReadKeepsWhatWasRead() async {
        let memo = LiveShotsMemo(freshFor: 0)
        _ = await memo.read(key) { live("a") }
        let failed = await memo.read(key) { throw URLError(.notConnectedToInternet) }
        #expect(failed == live("a"))
        #expect(memo.kept(key) == live("a"))
    }

    @Test func aFailedFirstReadKeepsNothing() async {
        let memo = LiveShotsMemo()
        let failed = await memo.read(key) { throw URLError(.notConnectedToInternet) }
        #expect(failed == nil)
        #expect(memo.needsRead(key))
    }

    @Test func previewsAskingTogetherShareOneRead() async {
        let memo = LiveShotsMemo()
        let counter = Counter()
        async let first = memo.read(key) {
            counter.reads += 1
            try await Task.sleep(for: .milliseconds(50))
            return live("a")
        }
        async let second = memo.read(key) {
            counter.reads += 1
            return live("b")
        }
        let results = await [first, second]
        #expect(counter.reads == 1)
        #expect(results.allSatisfy { $0 == live("a") })
    }
}
