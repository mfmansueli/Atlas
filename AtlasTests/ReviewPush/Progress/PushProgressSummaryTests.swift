//
//  PushProgressSummaryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The changes, screenshots and extras of a push counted as one: the
/// counts, the title and subtitle while it runs and once it's over, each
/// failure reason once across all three, and the time line.
@Suite("Push progress summary")
struct PushProgressSummaryTests {
    private static func entry(_ id: String, _ kind: PushProgressKind, _ state: PushProgressState) -> PushProgressEntry {
        PushProgressEntry(id: id, title: "Row \(id)", kind: kind, state: state)
    }

    /// A change.
    private static func entry(_ id: String, _ state: PushProgressState) -> PushProgressEntry {
        entry(id, .change, state)
    }

    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: - Counts

    @Test func countsEveryRowWhateverSendsIt() {
        let summary = PushProgressSummary(
            entries: [
                Self.entry("a", .done), Self.entry("b", .image, .sending), Self.entry("c", .video, .failed("Nope")),
                Self.entry("d", .image, .notSent), Self.entry("e", .waiting),
            ],
            isRunning: true
        )
        #expect(summary.totalCount == 5)
        #expect(summary.finishedCount == 3)
        #expect(summary.doneCount == 1)
        #expect(summary.failedCount == 1)
        #expect(summary.notSentCount == 1)
        #expect(summary.inFlightCount == 1)
        #expect(summary.progress == 0.6)
    }

    @Test func anEmptyPushHasNoProgress() {
        let summary = PushProgressSummary(entries: [], isRunning: false)
        #expect(summary.progress == 0)
        #expect(summary.failureGroups.isEmpty)
    }

    // MARK: - Title

    @Test func whileItRunsTheTitleSaysWhatItSends() {
        let summary = PushProgressSummary(
            entries: [Self.entry("a", .waiting), Self.entry("b", .waiting), Self.entry("c", .image, .sending)], isRunning: true
        )
        #expect(summary.contentsTitle == ["2 changes", "1 image"].formatted(.list(type: .and)))
        #expect(summary.title == "Pushing \(summary.contentsTitle)")
    }

    @Test func videosAreCountedApartFromImages() {
        let summary = PushProgressSummary(entries: [Self.entry("a", .video, .waiting), Self.entry("b", .video, .waiting)], isRunning: true)
        #expect(summary.title == "Pushing 2 videos")
    }

    @Test func whenEverythingWentTheTitleSaysAll() {
        let all = PushProgressSummary(entries: [Self.entry("a", .image, .done), Self.entry("b", .image, .done)], isRunning: false)
        #expect(all.title == "All 2 images pushed")
        let one = PushProgressSummary(entries: [Self.entry("a", .done)], isRunning: false)
        #expect(one.title == "1 change pushed")
    }

    @Test func whenSomethingDidntGoTheTitleCountsIt() {
        let failed = PushProgressSummary(
            entries: [Self.entry("a", .done), Self.entry("b", .done), Self.entry("c", .image, .failed("Nope"))], isRunning: false
        )
        #expect(failed.title == "2 pushed · 1 failed")
        let both = PushProgressSummary(
            entries: [Self.entry("a", .done), Self.entry("b", .failed("Nope")), Self.entry("c", .notSent)], isRunning: false
        )
        #expect(both.title == "1 pushed · 1 failed · 1 not sent")
        let cancelled = PushProgressSummary(entries: [Self.entry("a", .done), Self.entry("b", .notSent)], isRunning: false)
        #expect(cancelled.title == "1 pushed · 1 not sent")
    }

    // MARK: - Subtitle

    @Test func whileItRunsTheSubtitleSaysHowManyWentAndHowManyGoNow() {
        let summary = PushProgressSummary(
            entries: [Self.entry("a", .done), Self.entry("b", .sending), Self.entry("c", .sending), Self.entry("d", .waiting)], isRunning: true
        )
        #expect(summary.subtitle == "1 of 4 sent · 2 going now")
        let failing = PushProgressSummary(
            entries: [Self.entry("a", .done), Self.entry("b", .failed("Nope")), Self.entry("c", .waiting)], isRunning: true
        )
        #expect(failing.subtitle == "2 of 3 sent · 1 failed", "Nothing in flight, so no count of it")
    }

    @Test func onceItsOverTheSubtitleSaysWhatHappensToTheRest() {
        let failed = PushProgressSummary(entries: [Self.entry("a", .done), Self.entry("b", .failed("Nope"))], isRunning: false)
        #expect(failed.subtitle == "Failed ones stay in Review & Push: retry them, or fix them first.")
        let notSent = PushProgressSummary(entries: [Self.entry("a", .done), Self.entry("b", .notSent)], isRunning: false)
        #expect(notSent.subtitle == "1 not sent. They stay in Review & Push.")
        let all = PushProgressSummary(entries: [Self.entry("a", .done)], isRunning: false)
        #expect(all.subtitle == "Everything reached App Store Connect.")
    }

    // MARK: - Failures

    @Test func eachReasonShowsOnceAcrossChangesScreenshotsAndExtras() {
        let summary = PushProgressSummary(
            entries: [
                Self.entry("change", .failed("409 STATE_ERROR")), Self.entry("shot", .image, .failed("Upload timed out")),
                Self.entry("extra", .video, .failed("409 STATE_ERROR")), Self.entry("done", .done),
            ],
            isRunning: false
        )
        let groups = summary.failureGroups
        #expect(groups.map(\.reason) == ["409 STATE_ERROR", "Upload timed out"], "In the order they first happened")
        #expect(groups[0].titles == ["Row change", "Row extra"])
        #expect(groups[1].titles == ["Row shot"])
    }

    @Test func aLongGroupNamesTwoAndCountsTheRest() {
        let group = PushProgressFailureGroup(reason: "Nope", titles: ["A", "B", "C", "D", "E"])
        #expect(group.itemsTitle == "A, B and 3 more")
        let short = PushProgressFailureGroup(reason: "Nope", titles: ["A", "B"])
        #expect(short.itemsTitle == ["A", "B"].formatted(.list(type: .and)))
    }

    // MARK: - Time

    private func running(_ states: [PushProgressState], cancelling: Bool = false, pausedUntil: Date? = nil) -> PushProgressSummary {
        PushProgressSummary(
            entries: states.enumerated().map { Self.entry("\($0.offset)", $0.element) }, isRunning: true, isCancelling: cancelling,
            startedAt: Self.start, pausedUntil: pausedUntil
        )
    }

    @Test func untilOneGoesItSaysOnlyTheTimeSoFar() {
        let summary = running([.sending, .waiting])
        #expect(summary.timeTitle(now: Self.start.addingTimeInterval(30)) == "0:30 so far")
        #expect(summary.remainingSeconds(now: Self.start.addingTimeInterval(30)) == nil)
    }

    @Test func theRestIsEstimatedFromThePaceSoFar() {
        let summary = running([.done, .failed("Nope"), .sending, .waiting, .waiting, .waiting])
        let now = Self.start.addingTimeInterval(120)
        #expect(summary.remainingSeconds(now: now) == 240, "2 went in 2 min, 4 are left")
        #expect(summary.timeTitle(now: now) == "2:00 so far · about 4 min left")
    }

    @Test func nearTheEndItSaysLessThanAMinute() {
        let summary = running([.done, .done, .done, .done, .sending])
        #expect(summary.timeTitle(now: Self.start.addingTimeInterval(100)) == "1:40 so far · less than a minute left")
    }

    @Test func rowsThatWerentSentDontSetThePace() {
        let summary = running([.done, .notSent, .notSent, .waiting])
        #expect(summary.remainingSeconds(now: Self.start.addingTimeInterval(60)) == 60, "One went in a minute, one is left")
    }

    @Test func pausedThereIsNoEstimate() {
        let summary = running([.done, .waiting], pausedUntil: Self.start.addingTimeInterval(600))
        #expect(summary.remainingSeconds(now: Self.start.addingTimeInterval(60)) == nil)
        #expect(summary.timeTitle(now: Self.start.addingTimeInterval(60)) == "1:00 so far")
    }

    @Test func cancellingOnlyTheOnesInFlightAreLeft() {
        let summary = running([.done, .sending, .waiting, .waiting], cancelling: true)
        #expect(summary.remainingSeconds(now: Self.start.addingTimeInterval(60)) == 60)
    }

    @Test func onceItsOverThereIsNoTimeLine() {
        let summary = PushProgressSummary(entries: [Self.entry("a", .done)], isRunning: false, startedAt: Self.start)
        #expect(summary.timeTitle(now: Self.start.addingTimeInterval(60)) == nil)
    }
}
