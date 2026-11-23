//
//  ReleaseViewModelProposalTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// An assistant's proposal on Lumen Journal 1.4's version card: Confirm
/// runs the card's own action (asking first where it asks) and settles
/// it, Submit's choices go into the sheet, Dismiss takes it away, and one
/// the version no longer allows can't be confirmed.
@MainActor
@Suite("Release proposals on the card")
struct ReleaseViewModelProposalTests {
    typealias Data = DebugReleaseData

    private let release = FakeReleaseServices()
    private let queue = ChangeQueue()
    private let proposals = ReleaseProposalStore()
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]

    private func makeModel(_ phase: DebugReleasePhase, isWhatsNewComplete: Bool = false) async -> ReleaseViewModel {
        var services = ReleaseDebugScenes.services(phase)
        services.inAppEvents = DebugInAppEventsServices(events: nil)
        if isWhatsNewComplete {
            var storePage = DebugStorePageServices()
            storePage.whatsNew = Data.whatsNew.merging([Data.missingLocale: Data.suggestedWhatsNew]) { _, new in new }
            services.storePage = storePage
        }
        release.status = Data.status(phase)
        services.release = release
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let model = ReleaseViewModel(
            app: app, services: services, store: Data.store(phase), queue: queue, suggestions: FieldSuggestionStore(), push: push, events: InAppEventsStore()
        )
        model.now = { Data.today }
        model.linkClaims = ProjectLinkClaimsCenter()
        model.proposals = proposals
        await model.load()
        return model
    }

    @discardableResult
    private func propose(
        _ action: ReleaseProposal.Action, submission: ReleaseProposalSubmission? = nil, versionID: String = Data.versionID,
        versionString: String = Data.versionString
    ) -> ReleaseProposal {
        let proposal = ReleaseProposal(
            id: ReleaseProposal.makeID(), appID: app.id, versionID: versionID, versionString: versionString, platform: "IOS", action: action,
            submission: submission, evidence: AssistantEvidence(client: "Claude Code", summary: "", why: "Approved this morning.", evidence: []),
            receivedAt: Data.today
        )
        proposals.add(proposal)
        return proposal
    }

    @Test func confirmingAReleaseAsksFirstAndThenSettlesIt() async {
        let model = await makeModel(.pending)
        let proposal = propose(.release)
        #expect(model.waitingProposal == proposal)
        #expect(model.proposalProblem(proposal) == nil)

        #expect(!model.confirmProposal(proposal))
        #expect(model.confirming == .releaseNow, "The card's own question comes first")
        #expect(release.actions.isEmpty, "Nothing is sent before the person answers")

        await model.perform(.releaseNow)
        #expect(release.actions == ["release \(Data.versionID)"])
        #expect(proposals.proposal(id: proposal.id)?.status == .confirmed)
        #expect(model.waitingProposal == nil)
    }

    @Test func confirmingAPauseRunsTheCardsButton() async {
        let model = await makeModel(.phased)
        let proposal = propose(.pausePhasedRelease)
        #expect(!model.confirmProposal(proposal))
        #expect(model.confirming == nil, "Pause goes ahead, as the card's button does")
        for _ in 0..<100 where proposals.proposal(id: proposal.id)?.isPending == true {
            await Task.yield()
        }
        #expect(release.actions == ["phased \(Data.phasedID) PAUSED"])
        #expect(proposals.proposal(id: proposal.id)?.status == .confirmed)
    }

    @Test func aProposedSubmissionFillsTheSheetAndWaitsForSubmit() async throws {
        let model = await makeModel(.prepare, isWhatsNewComplete: true)
        let submission = ReleaseProposalSubmission(
            buildID: "build-211", buildNumber: "211", releaseType: "AFTER_APPROVAL", isPhased: false, encryption: "other", eventIDs: []
        )
        let proposal = propose(.submit, submission: submission)
        #expect(model.proposalLines(proposal) == [
            "Build 1.4 (211)", "Release right after approval", "Everyone on the first day", "Other encryption", "No In-App Events",
        ])
        #expect(model.confirmProposal(proposal), "The card opens the Submit sheet")
        #expect(model.options.buildID == "build-211")
        #expect(model.options.timing == .afterApproval)
        #expect(!model.options.isPhased)
        #expect(model.options.encryption == .other)
        #expect(model.options.eventIDs.isEmpty)
        #expect(release.plans.isEmpty, "Nothing goes to App Review before Submit")
        #expect(proposals.proposal(id: proposal.id)?.isPending == true)

        #expect(await model.submit())
        let plan = try #require(release.plans.first)
        #expect(plan.buildID == "build-211")
        #expect(plan.timing == .afterApproval)
        #expect(!plan.isPhased)
        #expect(plan.usesNonExemptEncryption == true, "Build 211 said no; the proposal's answer is written on it")
        #expect(plan.eventIDs.isEmpty)
        #expect(proposals.proposal(id: proposal.id)?.status == .confirmed)
    }

    @Test func aProposalTheVersionNoLongerAllowsCanOnlyBeDismissed() async throws {
        let model = await makeModel(.waiting)
        let proposal = propose(.release)
        let problem = try #require(model.proposalProblem(proposal))
        #expect(problem.contains("Pending Developer Release"))
        #expect(!model.confirmProposal(proposal))
        #expect(model.confirming == nil)

        model.dismissProposal(proposal)
        #expect(proposals.proposal(id: proposal.id)?.status == .dismissed)
        #expect(model.waitingProposal == nil)
        #expect(release.actions.isEmpty)
    }

    @Test func aProposalForAnotherVersionIsOutOfDate() async throws {
        let model = await makeModel(.pending)
        let older = propose(.release, versionID: "version-1.3", versionString: "1.3")
        #expect(try #require(model.proposalProblem(older)) == "It was for 1.3; the version now is 1.4.")
        let replaced = propose(.release, versionID: "version-1.4-old")
        #expect(try #require(model.proposalProblem(replaced)) == "It was for another 1.4 than the one now.")
    }
}
#endif
