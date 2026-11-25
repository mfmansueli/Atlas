//
//  WatchLedgerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Each finding's state between checks: sent once, back only when it moved
/// a lot or its week is over, never asked twice.
@MainActor
@Suite("Look for Improvements · ledger")
struct WatchLedgerTests {
    private typealias Data = WatchTestData
    private let signal = Data.signal()

    private func verdict(_ archive: WatchArchive, at date: Date = Data.now, dedupe: WatchDedupe = WatchDedupe()) -> WatchDecision.Verdict {
        WatchLedger.verdict(for: signal, in: archive, dedupe: dedupe, now: date)
    }

    private func observed(_ signals: [WatchSignal]? = nil, at date: Date = Data.now) -> WatchArchive {
        var archive = WatchArchive()
        WatchLedger.observe(signals ?? [signal], in: &archive, now: date)
        return archive
    }

    @Test func aNewFindingIsSent() {
        let archive = observed()
        #expect(archive.records[signal.identity]?.state == .new)
        #expect(verdict(archive) == .send)
    }

    @Test func aSentFindingWaitsAWeekBeforeGoingAgain() {
        var archive = observed()
        WatchLedger.markSent([signal], runID: UUID(), in: &archive, now: Data.now)
        #expect(archive.stats(for: .whatsNewMissing).lastSentAt == Data.now)
        #expect(verdict(archive, at: Data.now.addingTimeInterval(2 * Data.day)) == .skip(.alreadySent))
        #expect(verdict(archive, at: Data.now.addingTimeInterval(8 * Data.day)) == .send)
    }

    @Test func aDismissedFindingComesBackOnlyWhenItMovedALot() {
        var archive = observed()
        WatchLedger.decide(signal.identity, .dismissed(date: Data.now), in: &archive)
        #expect(archive.records[signal.identity]?.decidedValue == 3)
        #expect(verdict(archive) == .skip(.dismissed))

        WatchLedger.observe([Data.signal(value: 3.5)], in: &archive, now: Data.now)
        #expect(verdict(archive) == .skip(.dismissed))

        WatchLedger.observe([Data.signal(value: 5)], in: &archive, now: Data.now)
        #expect(archive.records[signal.identity]?.state == .new)
        #expect(archive.records[signal.identity]?.decidedValue == nil)
        #expect(verdict(archive) == .send)
    }

    @Test func anAcceptedFindingStaysAccepted() {
        var archive = observed()
        WatchLedger.decide(signal.identity, .accepted(date: Data.now), in: &archive)
        WatchLedger.observe([signal], in: &archive, now: Data.now.addingTimeInterval(Data.day))
        #expect(verdict(archive) == .skip(.accepted))
    }

    @Test func notNowWaitsUntilItsDay() {
        var archive = observed()
        let until = Data.now.addingTimeInterval(WatchLedger.snoozeTime)
        WatchLedger.decide(signal.identity, .snoozed(until: until), in: &archive)
        #expect(verdict(archive) == .skip(.snoozed(until: until)))
        WatchLedger.observe([signal], in: &archive, now: until)
        #expect(archive.records[signal.identity]?.state == .new)
        #expect(verdict(archive, at: until) == .send)
    }

    @Test func dontSuggestThisAgainSilencesTheKind() {
        var archive = observed()
        archive.updateStats(for: .whatsNewMissing) { $0.isSilenced = true }
        #expect(verdict(archive) == .skip(.silenced))
        #expect(WatchLedger.verdict(for: Data.signal(.crashesWorse), in: archive, dedupe: WatchDedupe(), now: Data.now) == .send)
    }

    @Test func aPausedKindAndOneNotDueWait() {
        var paused = observed()
        paused.updateStats(for: .whatsNewMissing) { $0.isPaused = true }
        #expect(verdict(paused) == .skip(.paused))

        var recent = observed()
        recent.updateStats(for: .whatsNewMissing) {
            $0.lastSentAt = Data.now.addingTimeInterval(-3600)
            $0.intervalMultiplier = 2
        }
        let next = Data.now.addingTimeInterval(-3600 + 2 * Data.day)
        #expect(verdict(recent) == .skip(.notDue(until: next)))
        #expect(verdict(recent, at: next) == .send)
    }

    @Test func localOnlyFindingsAreNeverSent() {
        let blocked = Data.signal(.submissionBlocked, subject: "v15", value: 1)
        let archive = observed([blocked])
        #expect(WatchLedger.verdict(for: blocked, in: archive, dedupe: WatchDedupe(), now: Data.now) == .localOnly)
        #expect(!WatchLedger.decide([blocked], in: archive, dedupe: WatchDedupe(), now: Data.now)[0].isSent)
    }

    @Test func dedupeSkipsWhatsAlreadySuggestedOrTurnedDown() {
        let archive = observed()
        #expect(verdict(archive, dedupe: WatchDedupe(waiting: [signal.identity])) == .skip(.alreadySuggested))
        #expect(verdict(archive, dedupe: WatchDedupe(dismissed: [signal.identity])) == .skip(.dismissedElsewhere))
    }

    @Test func aWhatsNewSuggestionDismissedThisWeekTurnsTheFindingDown() throws {
        let store = FieldSuggestionStore(now: { Data.now })
        let german = try #require(StoreLocaleCatalog.locale(code: "de-DE"))
        let added = store.add(
            appID: Data.lumen, target: .storePage(german, .whatsNew), value: "Neu", reason: "Commits", source: .assistant(client: "Claude Code")
        )
        let before = WatchDedupe.make(for: [signal], appID: Data.lumen, suggestions: store, findings: AnalyticsFindingsState(), now: Data.now)
        #expect(before.reason(for: signal) == nil)

        store.dismiss([added.suggestion.id])
        let after = WatchDedupe.make(for: [signal], appID: Data.lumen, suggestions: store, findings: AnalyticsFindingsState(), now: Data.now)
        #expect(after.reason(for: signal) == .dismissedElsewhere)

        let later = WatchDedupe.make(
            for: [signal], appID: Data.lumen, suggestions: store, findings: AnalyticsFindingsState(), now: Data.now.addingTimeInterval(8 * Data.day)
        )
        #expect(later.reason(for: signal) == nil)
    }

    @Test func recordsGoneForAMonthAreForgottenUnlessARunWaitsOnThem() {
        var archive = observed()
        let other = Data.signal(.crashesWorse, subject: "1.4")
        WatchLedger.observe([other], in: &archive, now: Data.now)
        archive.append(WatchHistoryEntry(id: UUID(), appID: Data.lumen, appName: "Lumen", startedAt: Data.now, signals: [other]))
        WatchLedger.observe([], in: &archive, now: Data.now.addingTimeInterval(31 * Data.day))
        #expect(archive.records[signal.identity] == nil)
        #expect(archive.records[other.identity] != nil)
    }

    @Test func thePersonsDecisionAboutAnUnknownFindingChangesNothing() {
        var archive = WatchArchive()
        WatchLedger.decide("nothing", .accepted(date: Data.now), in: &archive)
        #expect(archive.records.isEmpty)
    }
}
