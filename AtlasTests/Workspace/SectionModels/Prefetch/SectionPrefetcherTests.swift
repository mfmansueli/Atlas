//
//  SectionPrefetcherTests.swift
//  AtlasTests
//

import Foundation
import Synchronization
import Testing
@testable import Atlas

@MainActor
@Suite("SectionPrefetcher")
struct SectionPrefetcherTests {
    private let app = DebugFixtures.lumen
    private let models = WorkspaceSectionModels()

    /// What the shown section is, changeable from inside a read.
    @MainActor
    private final class Screen {
        var section: AppWorkspaceSection
        init(_ section: AppWorkspaceSection) { self.section = section }
    }

    /// The waits the prefetcher asked for.
    private final class Waits: Sendable {
        private let durations = Mutex<[Duration]>([])
        var all: [Duration] { durations.withLock { $0 } }
        func note(_ duration: Duration) { durations.withLock { $0.append(duration) } }
    }

    /// Holds a read until the test lets it finish.
    @MainActor
    private final class Gate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isOpen = false

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }

    private func prefetcher(sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> SectionPrefetcher {
        SectionPrefetcher(models: models, settleDelay: .seconds(2), sleep: sleep)
    }

    private func run(
        _ warmer: FakeSectionWarmer,
        shown: Screen = Screen(.overview),
        quota: @escaping () -> AppStoreConnectRateLimit? = { nil },
        prefetcher: SectionPrefetcher? = nil
    ) async {
        await (prefetcher ?? self.prefetcher()).prefetch(app, refreshCount: 0, using: warmer, shown: { shown.section }, quota: quota)
    }

    @Test func readsEverySectionButTheOneOnScreenInTheSidebarsOrder() async {
        let warmer = FakeSectionWarmer()
        await run(warmer, shown: Screen(.storePage))
        #expect(warmer.warmed == AppWorkspaceSection.allCases.filter { $0 != .storePage })
    }

    @Test func whatTheSectionsReadIsKeptForTheApp() async {
        let warmer = FakeSectionWarmer()
        await run(warmer)
        #expect(!models.models(for: app.id).needsLoad(.subscriptionPricing, refreshCount: 0))
    }

    @Test func freshSectionsAreLeftAlone() async {
        let warmer = FakeSectionWarmer(fresh: [.storePage, .reviews])
        await run(warmer)
        #expect(!warmer.warmed.contains(.storePage))
        #expect(!warmer.warmed.contains(.reviews))
        #expect(warmer.warmed.contains(.appInformation))
    }

    @Test func theSectionOnScreenIsAskedBeforeEachRead() async {
        let screen = Screen(.overview)
        let warmer = FakeSectionWarmer()
        // The person opens App Information while the Store Page is read.
        warmer.onWarm = { section in if section == .storePage { screen.section = .appInformation } }
        await run(warmer, shown: screen)
        #expect(warmer.warmed.contains(.overview) == false)
        #expect(warmer.warmed.contains(.storePage))
        #expect(!warmer.warmed.contains(.appInformation))
    }

    @Test func waitsTheSettleDelayBeforeReading() async {
        let waits = Waits()
        let warmer = FakeSectionWarmer()
        await run(warmer, prefetcher: prefetcher { waits.note($0) })
        #expect(waits.all == [.seconds(2)])
        #expect(SectionPrefetcher.settleDelay == .seconds(2))
    }

    @Test func readsNothingWhenTheAppChangesDuringTheWait() async {
        let warmer = FakeSectionWarmer()
        await run(warmer, prefetcher: prefetcher { _ in throw CancellationError() })
        #expect(warmer.warmed.isEmpty)
    }

    @Test func stopsBetweenSectionsOnceCancelled() async {
        let warmer = FakeSectionWarmer()
        var task: Task<Void, Never>?
        warmer.onWarm = { _ in task?.cancel() }
        task = Task { await run(warmer) }
        await task?.value
        #expect(warmer.warmed == [.storePage], "The read that started finished; no other started")
    }

    @Test func readsNothingWhileTheQuotaIsInItsLastQuarter() async {
        let warmer = FakeSectionWarmer()
        await run(warmer, quota: { AppStoreConnectRateLimit(limit: 3600, remaining: 900) })
        #expect(warmer.warmed.isEmpty)
    }

    @Test func stopsOnceTheQuotaFallsIntoItsLastQuarter() async {
        let warmer = FakeSectionWarmer()
        var remaining = 1000
        warmer.onWarm = { _ in remaining -= 60 }
        await run(warmer, quota: { AppStoreConnectRateLimit(limit: 3600, remaining: remaining) })
        #expect(warmer.warmed == [.storePage, .screenshots])
    }

    @Test func anUnknownQuotaDoesntStopIt() async {
        let warmer = FakeSectionWarmer()
        await run(warmer, quota: { nil })
        #expect(warmer.warmed.count == AppWorkspaceSection.allCases.count - 1)
    }

    @Test func aSectionAlreadyReadingAheadIsntReadAgain() async {
        let kept = models.models(for: app.id)
        let gate = Gate()
        let running = Task { await kept.warm(.storePage) { await gate.wait() } }
        for _ in 0..<10 {
            await Task.yield()
        }
        let warmer = FakeSectionWarmer()
        await run(warmer)
        #expect(!warmer.warmed.contains(.storePage))
        gate.open()
        await running.value
    }
}
