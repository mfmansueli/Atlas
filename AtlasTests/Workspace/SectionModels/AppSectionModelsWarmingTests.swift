//
//  AppSectionModelsWarmingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("AppSectionModels reading ahead")
struct AppSectionModelsWarmingTests {
    /// What the reads did.
    @MainActor
    private final class Log {
        var reads = 0
        var finishedUncancelled = false
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

    private func kept() -> AppSectionModels {
        AppSectionModels(maximumAge: 60) { Date(timeIntervalSince1970: 1_000_000) }
    }

    /// Lets the main actor run the tasks waiting on it.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    @Test func aSectionIsWarmingOnlyWhileItsReadRuns() async {
        let kept = kept()
        let gate = Gate()
        let read = Task { await kept.warm(.storePage) { await gate.wait() } }
        await settle()
        #expect(kept.isWarming(.storePage))
        #expect(!kept.isWarming(.subscriptionPricing))
        gate.open()
        await read.value
        #expect(!kept.isWarming(.storePage))
    }

    @Test func askingAgainWhileItReadsWaitsInsteadOfReadingTwice() async {
        let kept = kept()
        let gate = Gate()
        let log = Log()
        let first = Task {
            await kept.warm(.storePage) {
                log.reads += 1
                await gate.wait()
            }
        }
        await settle()
        let second = Task { await kept.warm(.storePage) { log.reads += 1 } }
        await settle()
        gate.open()
        await first.value
        await second.value
        #expect(log.reads == 1)
    }

    @Test func openingTheSectionWaitsForItsReadAhead() async {
        let kept = kept()
        let gate = Gate()
        let read = Task {
            await kept.warm(.appInformation) {
                await gate.wait()
                kept.didLoad(.appInformation, refreshCount: 0)
            }
        }
        await settle()
        let opening = Task {
            await kept.finishWarming(.appInformation)
            return kept.needsLoad(.appInformation, refreshCount: 0)
        }
        await settle()
        gate.open()
        await read.value
        #expect(await opening.value == false, "The section found what the read ahead stamped")
    }

    @Test func finishingWithoutAReadAheadReturnsAtOnce() async {
        let kept = kept()
        await kept.finishWarming(.reviews)
        #expect(kept.needsLoad(.reviews, refreshCount: 0))
    }

    @Test func theReadIsntCancelledWithItsCaller() async {
        let kept = kept()
        let log = Log()
        let caller = Task {
            await kept.warm(.screenshots) {
                await Task.yield()
                log.finishedUncancelled = !Task.isCancelled
            }
        }
        caller.cancel()
        await caller.value
        #expect(log.finishedUncancelled)
    }

    @Test func theStorePageForTheVersionWaitsForItsReadAheadAndKeepsIt() async {
        let kept = kept()
        let gate = Gate()
        let warmed = StorePageViewModel(app: DebugFixtures.lumen, services: DebugStorePageServices(), queue: ChangeQueue())
        let read = Task {
            await kept.warm(.storePage) {
                kept.storePage = warmed
                await gate.wait()
                await warmed.load()
            }
        }
        await settle()
        let asked = Task { await kept.loadedStorePage { Issue.record("A second model was made"); return warmed } }
        await settle()
        gate.open()
        await read.value
        #expect(await asked.value === warmed)
    }

    @Test func theStorePageForTheVersionIsMadeAndKeptWhenThereIsNone() async {
        let kept = kept()
        let page = await kept.loadedStorePage {
            StorePageViewModel(app: DebugFixtures.lumen, services: DebugStorePageServices(), queue: ChangeQueue())
        }
        #expect(page?.isLoaded == true)
        #expect(kept.storePage === page)
    }

    @Test func aStorePageThatCantLoadIsntGivenToTheVersion() async {
        let kept = kept()
        let page = await kept.loadedStorePage {
            StorePageViewModel(app: DebugFixtures.lumen, services: DebugStorePageServices(error: .unexpectedPayload), queue: ChangeQueue())
        }
        #expect(page == nil)
    }
}
