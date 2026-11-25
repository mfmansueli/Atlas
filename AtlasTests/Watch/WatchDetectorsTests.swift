//
//  WatchDetectorsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The detectors read only what a check already has: each finds its kind,
/// and says nothing when there's nothing to say.
@Suite("Look for Improvements · detectors")
struct WatchDetectorsTests {
    private typealias Data = WatchTestData

    // MARK: - What's New

    @Test func whatsNewMissingWithCommitsSinceTheLastTag() throws {
        let signal = try #require(WatchDetectors.whatsNew(Data.whatsNewInputs()))
        #expect(signal.kind == .whatsNewMissing)
        #expect(signal.subject == "1.5")
        #expect(signal.value == 3)
        #expect(signal.summary.contains("3 of 8 languages (de-DE, ja, pt-BR)"))
        #expect(signal.summary.contains("14 commits since v1.4"))
    }

    @Test func whatsNewNeedsCommitsAPreparedVersionAndAMissingLanguage() {
        var noCommits = Data.whatsNewInputs()
        noCommits.commits = nil
        var zeroCommits = Data.whatsNewInputs()
        zeroCommits.commits = WatchInputs.Commits(tag: "v1.4", count: 0)
        var live = Data.whatsNewInputs()
        live.version?.phase = .live
        var complete = Data.whatsNewInputs()
        complete.whatsNew?.missing = []
        for inputs in [noCommits, zeroCommits, live, complete] {
            #expect(WatchDetectors.whatsNew(inputs) == nil)
        }
    }

    // MARK: - Events

    @Test func anEventShowingWithinAWeekWithIssues() throws {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.events = [Data.event()]
        let signal = try #require(WatchDetectors.events(inputs).first)
        #expect(signal.kind == .eventDeadline)
        #expect(signal.subject == "e1")
        #expect(signal.value == 2)
        #expect(signal.deadline == Data.now.addingTimeInterval(3 * Data.day))
        #expect(signal.summary.contains("in 3 days"))
        #expect(signal.summary.contains("eventId e1"))
    }

    @Test func eventsLaterPastLockedOrCompleteSayNothing() {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.events = [
            Data.event(id: "later", in: 8),
            Data.event(id: "past", in: -1),
            Data.event(id: "locked", editable: false),
            Data.event(id: "done", missing: [], languages: []),
        ]
        #expect(WatchDetectors.events(inputs).isEmpty)
    }

    // MARK: - Crashes

    @Test func crashesClearlyWorseInTheNewVersion() throws {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.stability = Data.stability(latest: 96, previous: 30, comparison: .higher(.sure))
        let signal = try #require(WatchDetectors.crashes(inputs))
        #expect(signal.subject == "1.4")
        #expect(abs(signal.value - 3.2) < 0.001)
        #expect(signal.summary.contains("3.2× as often as 1.3"))
        #expect(signal.summary.contains("3.2 per 1,000 sessions"))
    }

    @Test func crashesThatCouldBeChanceSayNothing() {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.stability = Data.stability(latest: 31, previous: 30, comparison: .same)
        #expect(WatchDetectors.crashes(inputs) == nil)
    }

    // MARK: - Reviews

    @Test func manyLowReviewsSinceTheRelease() throws {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.reviewedVersion = "1.4"
        inputs.reviews = (0..<8).map { Data.review($0, rating: $0 < 4 ? 1 : 5) }
        let signal = try #require(WatchDetectors.reviews(inputs))
        #expect(signal.subject == "1.4")
        #expect(signal.value == 8)
        #expect(signal.numbers["low"] == 4)
    }

    @Test func aRatingDropAgainstTheReviewsBefore() throws {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.reviewedVersion = "1.4"
        inputs.reviews = (0..<6).map { Data.review($0, rating: 4) } + (0..<6).map { Data.review($0, rating: 5, version: "1.3", daysAgo: 20) }
        let signal = try #require(WatchDetectors.reviews(inputs))
        #expect(signal.summary.contains("against 5★ in the 6 before"))
    }

    @Test func reviewsAlreadyGroupedOrTooFewSayNothing() {
        var grouped = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        grouped.reviewedVersion = "1.4"
        grouped.reviews = (0..<8).map { Data.review($0, rating: $0 < 4 ? 1 : 5) }
        grouped.themes = [ReviewTheme(
            id: "sync", title: "Sync", note: "", reviewIDs: grouped.reviews.filter(\.isLow).map(\.id), action: .replyToAll, source: "Claude Code"
        )]
        #expect(WatchDetectors.reviews(grouped) == nil)

        var few = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        few.reviewedVersion = "1.4"
        few.reviews = (0..<4).map { Data.review($0, rating: 1) }
        #expect(WatchDetectors.reviews(few) == nil)

        var happy = few
        happy.reviews = (0..<8).map { Data.review($0, rating: 5) }
        #expect(WatchDetectors.reviews(happy) == nil)
    }

    @Test func withoutAReviewedVersionReviewsSplitAtTheDayItWentOut() throws {
        var inputs = WatchInputs(appID: Data.lumen, appName: "Lumen", now: Data.now)
        inputs.version = WatchInputs.Version(id: "v14", versionString: "1.4", phase: .live, liveSince: Data.now.addingTimeInterval(-5 * Data.day))
        inputs.reviews = (0..<6).map { Data.review($0, rating: 1, version: "") }
        let signal = try #require(WatchDetectors.reviews(inputs))
        #expect(signal.subject == "1.4")
    }

    // MARK: - Local only

    @Test func aBlockedOrRejectedVersionIsAtlassOwn() throws {
        var blocked = WatchInputs(appID: Data.tempo, appName: "Tempo", now: Data.now)
        blocked.version = WatchInputs.Version(id: "t21", versionString: "2.1", phase: .prepare)
        blocked.blockers = [.exportCompliance, .ageRating]
        let signal = try #require(WatchDetectors.blocked(blocked))
        #expect(signal.kind == .submissionBlocked)
        #expect(signal.subject == "t21")
        #expect(signal.value == 2)

        var rejected = blocked
        rejected.version?.phase = .rejected
        #expect(WatchDetectors.blocked(rejected) == nil)
        #expect(WatchDetectors.rejected(rejected)?.kind == .versionRejected)
        #expect(WatchDetectors.rejected(blocked) == nil)
    }

    @Test func signalsComeInKindOrder() {
        var inputs = Data.whatsNewInputs()
        inputs.blockers = [.appReviewInformation]
        inputs.events = [Data.event()]
        inputs.stability = Data.stability(latest: 96, previous: 30, comparison: .higher(.sure))
        let kinds = WatchDetectors.signals(in: inputs).map(\.kind)
        #expect(kinds == [.submissionBlocked, .eventDeadline, .whatsNewMissing, .crashesWorse])
    }

    @Test func eventFactsFromAnEventLeaveOutSuggestedLanguages() {
        let event = DebugInAppEventsData.winter
        let facts = WatchEventFacts(event, storeLocales: ["en-US", "en-GB", "fr-FR", "xx-XX"], suggestedLocales: ["xx-XX"], now: Data.now)
        #expect(facts.id == event.id)
        #expect(!facts.missingLanguages.contains("xx-XX"))
        #expect(!facts.missingLanguages.contains("en-US"))
        #expect(facts.deadline == event.dates?.publishStart)
    }
}
