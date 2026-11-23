//
//  ReleaseSubmitProposalToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_release_action` with submit on Lumen Journal 1.4: checked
/// like the Submit sheet (a build App Review can take, What's New in
/// every language, an encryption answer, a date ahead, events that can
/// go), refused with how to fix it, and otherwise kept with its choices.
@MainActor
@Suite("Proposing a submission")
struct ReleaseSubmitProposalToolTests {
    @Test func aSubmissionIsKeptWithItsChoices() async throws {
        let fixtures = MCPReleaseFixtures(.prepare)
        let result = try await fixtures.propose("submit", [
            "buildNumber": "211", "releaseType": "AFTER_APPROVAL", "phasedRelease": false, "eventIds": [.string(DebugInAppEventsData.moodID)],
        ])
        #expect(result["status"] == "queued")
        let notes = try #require(MCPReleaseFixtures.strings(result["notes"]))
        #expect(notes.contains { $0.contains("What’s New in it waits as a suggestion") })
        let id = try #require(result["proposalId"]?.stringValue)
        let submission = try #require(fixtures.proposals.proposal(id: id)?.submission)
        #expect(submission.buildID == "build-211")
        #expect(submission.buildNumber == "211")
        #expect(submission.timing == .afterApproval)
        #expect(!submission.isPhased)
        #expect(submission.encryption == nil, "Build 211 carries its answer")
        #expect(submission.eventIDs == [DebugInAppEventsData.moodID])
        #expect(fixtures.release.plans.isEmpty, "Nothing goes to App Review")

        let read = try await fixtures.get()
        let listed = try #require(read["proposals"]?.arrayValue?.first)
        #expect(listed["submit"]?["buildNumber"] == "211")
        #expect(listed["submit"]?["releaseType"] == "AFTER_APPROVAL")
    }

    @Test func withoutAnEncryptionAnswerItIsRefused() async throws {
        let fixtures = MCPReleaseFixtures(.prepare)
        let refused = try await fixtures.propose("submit")
        #expect(refused["status"] == "refused")
        let reasons = try #require(MCPReleaseFixtures.strings(refused["reasons"]))
        #expect(reasons.count == 1)
        #expect(reasons[0].contains("get_export_compliance"))

        let answered = try await fixtures.propose("submit", ["encryption": "exempt"])
        #expect(answered["status"] == "queued")
        let id = try #require(answered["proposalId"]?.stringValue)
        #expect(fixtures.proposals.proposal(id: id)?.submission?.buildID == "build-212")
        #expect(fixtures.proposals.proposal(id: id)?.submission?.encryptionAnswer == .exempt)
        #expect(fixtures.proposals.proposal(id: id)?.submission?.eventIDs == nil, "The sheet's ticks stay")
    }

    @Test func aBuildAppleIsStillProcessingIsRefused() async throws {
        let fixtures = MCPReleaseFixtures(.prepare, encryption: .exempt)
        let result = try await fixtures.propose("submit", ["buildNumber": "213"])
        let reasons = try #require(MCPReleaseFixtures.strings(result["reasons"]))
        #expect(reasons == ["Build 213 can’t go to App Review: Apple is still processing it. Ready: 212 or 211."])

        let unknown = try await fixtures.propose("submit", ["buildId": "build-999"])
        #expect(unknown["reasons"]?.arrayValue?.first?.stringValue?.contains("has no such build") == true)
    }

    @Test func missingWhatsNewIsRefusedWithHowToWriteIt() async throws {
        var fixtures = MCPReleaseFixtures(.prepare, encryption: .exempt)
        fixtures.suggestions = FieldSuggestionStore()
        let result = try await fixtures.propose("submit")
        let reasons = try #require(MCPReleaseFixtures.strings(result["reasons"]))
        #expect(reasons.count == 1)
        #expect(reasons[0].contains("Italian (it)"))
        #expect(reasons[0].contains("suggest_fields"))
    }

    @Test func aReleaseDateMustBeAhead() async throws {
        let fixtures = MCPReleaseFixtures(.prepare, encryption: .exempt)
        let passed = try await fixtures.propose("submit", ["releaseType": "SCHEDULED", "releaseDate": "2026-11-01T09:00:00Z"])
        #expect(passed["reasons"]?.arrayValue?.first?.stringValue?.contains("has passed") == true)
        let undated = try await fixtures.propose("submit", ["releaseType": "SCHEDULED"])
        #expect(undated["reasons"]?.arrayValue?.first?.stringValue?.contains("needs releaseDate") == true)

        let ahead = try await fixtures.propose("submit", ["releaseType": "SCHEDULED", "releaseDate": "2026-11-20T09:30:00Z"])
        #expect(ahead["status"] == "queued")
        let id = try #require(ahead["proposalId"]?.stringValue)
        let date = try #require(AppStoreConnectDate.date("2026-11-20T09:00:00Z"))
        #expect(fixtures.proposals.proposal(id: id)?.submission?.timing == .scheduled(date), "On the hour")
    }

    @Test func anEventThatCantGoIsRefused() async throws {
        let fixtures = MCPReleaseFixtures(.prepare, encryption: .exempt)
        let result = try await fixtures.propose("submit", ["eventIds": ["event-404"]])
        let reason = try #require(result["reasons"]?.arrayValue?.first?.stringValue)
        #expect(reason.contains("event-404"))
        #expect(reason.contains("Mood Calendar"))
    }

    @Test func aVersionAlreadyWithAppReviewIsntSubmittedAgain() async throws {
        let fixtures = MCPReleaseFixtures(.review)
        let result = try await fixtures.propose("submit", ["encryption": "exempt"])
        #expect(result["status"] == "refused")
        #expect(result["reason"]?.stringValue?.contains("submitted already") == true)
        #expect(result["possibleActions"] == [])
    }
}
#endif
