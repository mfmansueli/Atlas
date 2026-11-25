//
//  WatchBackoffTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What the person makes of each kind stretches it, pauses it, or brings it
/// back; and how each finding's outcome is read.
@Suite("Look for Improvements · backoff")
struct WatchBackoffTests {
    private typealias Data = WatchTestData

    @Test func threeDismissalsInARowPauseAndAskOnce() {
        var stats = WatchKindStats()
        WatchBackoff.record([.dismissed, .dismissed], runID: UUID(), in: &stats)
        #expect(!stats.isPaused)
        WatchBackoff.record([.dismissed], runID: UUID(), in: &stats)
        #expect(stats.isPaused)
        #expect(stats.asksKeepSuggesting)

        WatchBackoff.keepSuggesting(true, stats: &stats)
        #expect(!stats.isPaused)
        #expect(!stats.asksKeepSuggesting)
        #expect(!stats.isSilenced)

        WatchBackoff.record([.dismissed, .dismissed, .dismissed], runID: UUID(), in: &stats)
        #expect(stats.isPaused)
        #expect(!stats.asksKeepSuggesting)
    }

    @Test func anAcceptanceBreaksTheRow() {
        var stats = WatchKindStats()
        WatchBackoff.record([.dismissed, .dismissed, .accepted, .dismissed], runID: UUID(), in: &stats)
        #expect(stats.dismissalsInARow == 1)
        #expect(!stats.isPaused)
        WatchBackoff.record([.ignored], runID: UUID(), in: &stats)
        #expect(stats.dismissalsInARow == 1)
    }

    @Test func keepSuggestingNoSilencesTheKind() {
        var stats = WatchKindStats(isPaused: true, asksKeepSuggesting: true)
        WatchBackoff.keepSuggesting(false, stats: &stats)
        #expect(stats.isSilenced)
        #expect(stats.hasAskedKeepSuggesting)
    }

    @Test func underAFifthOverFiveBatchesDoublesTheInterval() {
        var stats = WatchKindStats()
        for _ in 0..<4 {
            WatchBackoff.record([.ignored], runID: UUID(), in: &stats)
        }
        #expect(stats.intervalMultiplier == 1)
        WatchBackoff.record([.ignored], runID: UUID(), in: &stats)
        #expect(stats.intervalMultiplier == 2)
        WatchBackoff.record([.ignored], runID: UUID(), in: &stats)
        #expect(stats.intervalMultiplier == 4)
        #expect(stats.batches.count == WatchBackoff.window)
        #expect(WatchBackoff.interval(for: .crashesWorse, stats: stats) == 4 * 24 * 3600)
    }

    @Test func theIntervalStopsAt16AndShrinksWhenThePersonTakesThem() {
        var stats = WatchKindStats()
        for _ in 0..<12 {
            WatchBackoff.record([.ignored], runID: UUID(), in: &stats)
        }
        #expect(stats.intervalMultiplier == WatchBackoff.longestMultiplier)
        WatchBackoff.record([.accepted, .edited], runID: UUID(), in: &stats)
        // 2 of 6 taken: a third.
        #expect(stats.intervalMultiplier == 8)
    }

    @Test func nextDateIsTheLastRunPlusTheInterval() {
        var stats = WatchKindStats()
        #expect(WatchBackoff.nextDate(for: .crashesWorse, stats: stats) == nil)
        stats.lastSentAt = Data.now
        stats.intervalMultiplier = 2
        #expect(WatchBackoff.nextDate(for: .crashesWorse, stats: stats) == Data.now.addingTimeInterval(2 * Data.day))
    }

    @Test func batchOutcomesCount() {
        let batch = WatchBatchOutcome(runID: UUID(), outcomes: [.accepted, .edited, .dismissed, .ignored, .ignored])
        #expect(batch.total == 5)
        #expect(batch.taken == 2)
        #expect(batch.ignored == 2)
    }

    // MARK: - Outcomes

    private func outcome(
        _ signal: WatchSignal = Data.signal(), state: WatchSignalState = .sent(runID: UUID(), date: Data.now), found: Bool = true,
        suggestions: WatchOutcomes.Suggestions = WatchOutcomes.Suggestions(), days: Double = 1
    ) -> WatchSignalOutcome? {
        let record = WatchRecord(signal: signal, state: state, firstSeen: Data.now, lastSeen: Data.now)
        return WatchOutcomes.outcome(
            of: signal, record: record, isStillFound: found, suggestions: suggestions, sentAt: Data.now,
            now: Data.now.addingTimeInterval(days * Data.day)
        )
    }

    @Test func thePersonsAnswerOnTheFindingComesFirst() {
        #expect(outcome(state: .accepted(date: Data.now)) == .accepted)
        #expect(outcome(state: .dismissed(date: Data.now), suggestions: .init(accepted: 1)) == .dismissed)
    }

    @Test func taggedSuggestionsSayWhatThePersonDid() {
        #expect(outcome(suggestions: .init(accepted: 1, edited: 1)) == .edited)
        #expect(outcome(suggestions: .init(accepted: 1, dismissed: 2)) == .accepted)
        #expect(outcome(suggestions: .init(dismissed: 2)) == .dismissed)
        #expect(outcome(suggestions: .init(dismissed: 1, open: 1)) == nil)
    }

    @Test func aFindingFixedAfterTheRunCountsAsTaken() {
        #expect(outcome(found: false) == .accepted)
        let event = Data.signal(.eventDeadline, subject: "e1", deadline: Data.now.addingTimeInterval(-Data.day))
        #expect(outcome(event, found: false) == nil)
        #expect(outcome(event, found: false, days: 8) == .ignored)
    }

    @Test func nothingForAWeekIsIgnored() {
        #expect(outcome(days: 6) == nil)
        #expect(outcome(days: 7) == .ignored)
    }
}
