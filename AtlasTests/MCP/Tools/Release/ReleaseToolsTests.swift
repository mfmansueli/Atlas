//
//  ReleaseToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_release`, `propose_release_action` and `withdraw_release_action`
/// on Lumen Journal 1.4: what the card shows, read for an assistant; a
/// proposal waits for the person and never reaches App Store Connect; a
/// state that doesn't allow it is refused with what's possible.
@MainActor
@Suite("Release tools")
struct ReleaseToolsTests {
    @Test func theToolsAreOfferedAndTheInstructionsNameThem() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["get_release", "propose_release_action", "withdraw_release_action"]))
        #expect(MCPEndpoint.instructions.contains("get_release"))
        #expect(MCPEndpoint.instructions.contains("propose_release_action"))
        #expect(MCPEndpoint.instructions.contains("withdraw_release_action"))
        #expect(GetReleaseTool().definition.isReadOnly)
        #expect(ProposeReleaseActionTool().definition.proposalKind == .storeText)
        #expect(!WithdrawReleaseActionTool().definition.isReadOnly)
    }

    @Test func beforeSubmittingItSaysWhatIsReadyAndWhatIsMissing() async throws {
        let fixtures = MCPReleaseFixtures(.prepare)
        let result = try await fixtures.get()
        let iOS = try #require(result["platforms"]?.arrayValue?.first)
        #expect(iOS["platform"] == "IOS")
        #expect(iOS["version"]?["versionString"] == "1.4")
        #expect(iOS["version"]?["phase"] == "prepare")
        #expect(iOS["releaseType"] == "MANUAL")
        #expect(iOS["builds"]?.arrayValue?.compactMap { $0["buildNumber"]?.stringValue } == ["213", "212", "211"])
        #expect(iOS["defaultBuildId"] == "build-212")
        #expect(iOS["attachedBuild"]?["buildNumber"] == "212")
        #expect(iOS["whatsNew"]?["languages"] == 10)
        #expect(iOS["whatsNew"]?["missing"] == [])
        #expect(iOS["whatsNew"]?["suggested"] == ["it"])
        #expect(iOS["encryption"] == .null, "Build 212 has no answer and Export Compliance none")
        #expect(iOS["reviewInformationComplete"] == true)
        let offered = try #require(iOS["offeredEvents"]?.arrayValue)
        #expect(offered.contains { $0["id"] == .string(DebugInAppEventsData.moodID) })
        let blockers = try #require(MCPReleaseFixtures.strings(iOS["submitBlockers"]))
        #expect(blockers == ["add What’s New in Italian", "answer the encryption question"])
        #expect(iOS["possibleActions"]?.arrayValue?.compactMap { $0["action"]?.stringValue } == ["submit"])
        #expect(iOS["rejection"] == nil)
        #expect(result["proposals"] == [])
    }

    @Test func aPhasedReleaseSaysItsDayAndShare() async throws {
        let result = try await MCPReleaseFixtures(.phased).get(["platform": "ios"])
        let iOS = try #require(result["platforms"]?.arrayValue?.first)
        #expect(iOS["version"]?["phase"] == "phased")
        #expect(iOS["phasedRelease"]?["state"] == "ACTIVE")
        #expect(iOS["phasedRelease"]?["day"] == 3)
        #expect(iOS["phasedRelease"]?["percentage"] == 5)
        #expect(iOS["builds"] == nil, "Only before submitting")
        #expect(iOS["possibleActions"]?.arrayValue?.compactMap { $0["action"]?.stringValue } == ["pause_phased_release", "complete_phased_release"])
    }

    @Test func aSubmissionListsWhatIsInItAndARejectionWhereItsMessageIs() async throws {
        let waiting = try await MCPReleaseFixtures(.waiting).get()
        let submission = try #require(waiting["platforms"]?.arrayValue?.first?["submission"])
        #expect(submission["state"] == "WAITING_FOR_REVIEW")
        let items = try #require(submission["items"]?.arrayValue)
        #expect(items.first?["type"] == "appStoreVersion")
        #expect(items.last?["type"] == "appEvent")
        #expect(items.last?["name"] == "Mood Calendar")

        let rejected = try await MCPReleaseFixtures(.rejected).get()
        let iOS = try #require(rejected["platforms"]?.arrayValue?.first)
        #expect(iOS["rejection"]?["submissionState"] == "UNRESOLVED_ISSUES")
        #expect(iOS["rejection"]?["resubmitsDirectly"] == true)
        #expect(iOS["rejection"]?["message"] == .null)
        #expect(iOS["rejection"]?["messageNote"]?.stringValue?.contains("ask the person") == true)
        #expect(iOS["possibleActions"]?.arrayValue?.compactMap { $0["action"]?.stringValue } == ["submit", "resubmit"])
    }

    @Test func aProposalWaitsForThePersonAndSendsNothing() async throws {
        let fixtures = MCPReleaseFixtures(.pending)
        let result = try await fixtures.propose("release", ["versionString": "1.4", "evidence": ["get_in_app_events — Mood Calendar starts Nov 20"]])
        #expect(result["status"] == "queued")
        #expect(result["action"] == "release")
        #expect(result["versionString"] == "1.4")
        let id = try #require(result["proposalId"]?.stringValue)
        let kept = try #require(fixtures.proposals.proposal(id: id))
        #expect(kept.isPending)
        #expect(kept.client == "Claude Code")
        #expect(kept.evidence.why == "Approved this morning; the event starts Friday.")
        #expect(kept.evidence.evidence == ["get_in_app_events — Mood Calendar starts Nov 20"])
        #expect(kept.versionID == DebugReleaseData.versionID)
        #expect(fixtures.release.actions.isEmpty, "Nothing reaches App Store Connect")

        let again = try await fixtures.propose("release", ["evidence": ["get_in_app_events — Mood Calendar starts Nov 20"]])
        #expect(again["status"] == "unchanged")
        #expect(again["proposalId"] == .string(id))

        let read = try await fixtures.get()
        let listed = try #require(read["proposals"]?.arrayValue?.first)
        #expect(listed["proposalId"] == .string(id))
        #expect(listed["status"] == "pending")
    }

    @Test func aStateThatDoesntAllowItIsRefusedWithWhatIsPossible() async throws {
        let fixtures = MCPReleaseFixtures(.waiting)
        let result = try await fixtures.propose("release")
        #expect(result["status"] == "refused")
        #expect(result["reason"]?.stringValue?.contains("Pending Developer Release") == true)
        #expect(result["possibleActions"] == ["cancel_submission"])
        #expect(fixtures.proposals.proposals.isEmpty)

        let other = try await fixtures.propose("release", ["versionString": "1.5"])
        #expect(other["status"] == "refused")
        #expect(other["reason"]?.stringValue?.contains("is 1.4, not 1.5") == true)

        await #expect(throws: MCPToolError.self) { try await fixtures.propose("ship_it") }
    }

    @Test func aNewProposalReplacesYoursAndAnotherAssistantsWaits() async throws {
        let fixtures = MCPReleaseFixtures(.phased)
        let pause = try #require(try await fixtures.propose("pause_phased_release")["proposalId"]?.stringValue)
        let complete = try await fixtures.propose("complete_phased_release")
        #expect(complete["status"] == "queued")
        #expect(complete["replaced"] == .array([.string(pause)]))

        let codex = try await fixtures.propose("pause_phased_release", client: "Codex")
        #expect(codex["status"] == "refused")
        #expect(codex["reason"]?.stringValue?.contains("Claude Code’s proposal") == true)
        #expect(fixtures.proposals.pending(for: DebugFixtures.AppID.lumen).count == 1)
    }

    @Test func onlyYourOwnWaitingProposalIsWithdrawn() async throws {
        let fixtures = MCPReleaseFixtures(.pending)
        let id = try #require(try await fixtures.propose("release")["proposalId"]?.stringValue)

        let byCodex = try await fixtures.withdraw(["proposalId": .string(id)], client: "Codex")
        #expect(byCodex["status"] == "unchanged")
        #expect(byCodex["left"]?.arrayValue?.first?["reason"]?.stringValue?.contains("not by you") == true)

        let mine = try await fixtures.withdraw()
        #expect(mine["status"] == "withdrawn")
        #expect(mine["withdrawn"]?.arrayValue?.first?["proposalId"] == .string(id))
        #expect(fixtures.proposals.proposal(id: id)?.status == .withdrawn)

        let read = try await fixtures.get()
        #expect(read["proposals"]?.arrayValue?.first?["status"] == "withdrawn")
    }

    /// A proposal made before the version moved on is listed as outdated,
    /// with why.
    @Test func aProposalTheVersionMovedPastIsOutdated() async throws {
        let fixtures = MCPReleaseFixtures(.pending)
        _ = try await fixtures.propose("release")
        fixtures.release.status = DebugReleaseData.status(.phased)
        let listed = try #require(try await fixtures.get()["proposals"]?.arrayValue?.first)
        #expect(listed["status"] == "outdated")
        #expect(listed["whyOutdated"]?.stringValue?.contains("Possible now: pause_phased_release or complete_phased_release.") == true)
    }
}
#endif
