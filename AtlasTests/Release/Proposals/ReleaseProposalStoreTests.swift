//
//  ReleaseProposalStoreTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The release proposals kept between launches: one waiting per app,
/// platform and assistant, settled by the person or the assistant, and
/// only the latest settled ones kept.
@MainActor
@Suite("Release proposal store")
struct ReleaseProposalStoreTests {
    private func proposal(
        _ action: ReleaseProposal.Action = .release, id: String = ReleaseProposal.makeID(), client: String = "Claude Code", platform: String? = "IOS"
    ) -> ReleaseProposal {
        ReleaseProposal(
            id: id, appID: DebugFixtures.AppID.lumen, versionID: DebugReleaseData.versionID, versionString: "1.4", platform: platform, action: action,
            evidence: AssistantEvidence(client: client, summary: "", why: "Approved this morning.", evidence: []),
            receivedAt: DebugReleaseData.today
        )
    }

    @Test func aNewProposalReplacesTheSameAssistantsOwn() {
        let store = ReleaseProposalStore()
        let first = proposal(.pausePhasedRelease, id: "rp-1")
        store.add(first)
        let other = proposal(.release, id: "rp-2", client: "Codex")
        store.add(other)
        let mac = proposal(.release, id: "rp-3", platform: "MAC_OS")
        store.add(mac)

        let replaced = store.add(proposal(.completePhasedRelease, id: "rp-4"))
        #expect(replaced == ["rp-1"])
        #expect(store.proposal(id: "rp-1")?.status == .replaced)
        #expect(store.pending(for: DebugFixtures.AppID.lumen).map(\.id) == ["rp-2", "rp-3", "rp-4"])
    }

    @Test func settlingConfirmsOnlyWhatWasDone() {
        let store = ReleaseProposalStore()
        store.add(proposal(.release, id: "rp-1"))
        store.add(proposal(.cancelSubmission, id: "rp-2", client: "Codex"))
        store.settle(.release, appID: DebugFixtures.AppID.lumen, versionID: DebugReleaseData.versionID)
        #expect(store.proposal(id: "rp-1")?.status == .confirmed)
        #expect(store.proposal(id: "rp-1")?.resolvedAt != nil)
        #expect(store.proposal(id: "rp-2")?.isPending == true)

        #expect(store.resolve("rp-2", as: .dismissed))
        #expect(!store.resolve("rp-2", as: .withdrawn), "Settled already")
        #expect(store.proposal(id: "rp-2")?.status == .dismissed)
        #expect(store.pending(for: DebugFixtures.AppID.lumen).isEmpty)
    }

    @Test func proposalsAreKeptBetweenLaunches() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReleaseProposalStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ReleaseProposalStore(directory: directory)
        var submit = proposal(.submit, id: "rp-1")
        submit.submission = ReleaseProposalSubmission(
            buildID: "build-211", buildNumber: "211", releaseType: "SCHEDULED", releaseDate: DebugReleaseData.date(day: 20, hour: 9), isPhased: false,
            encryption: "exempt", eventIDs: [DebugInAppEventsData.moodID]
        )
        store.add(submit)

        let reopened = ReleaseProposalStore(directory: directory)
        let kept = try #require(reopened.proposal(id: "rp-1"))
        #expect(kept == submit)
        #expect(kept.submission?.timing == .scheduled(DebugReleaseData.date(day: 20, hour: 9)))
        #expect(kept.submission?.encryptionAnswer == .exempt)
    }

    @Test func onlyTheLatestSettledOnesAreKept() {
        let store = ReleaseProposalStore()
        for index in 0..<ReleaseProposalStore.keptPerApp + 5 {
            store.add(proposal(id: "rp-\(index)"))
        }
        // Every one but the last was replaced by the next.
        let lumen = store.proposals(for: DebugFixtures.AppID.lumen)
        #expect(lumen.count == ReleaseProposalStore.keptPerApp + 1)
        #expect(lumen.last?.id == "rp-\(ReleaseProposalStore.keptPerApp + 4)")
        #expect(lumen.last?.isPending == true)
        #expect(store.proposal(id: "rp-0") == nil)
    }

    @Test func theSameRequestIsRecognised() {
        let one = proposal(.release, id: "rp-1")
        var again = proposal(.release, id: "rp-2")
        again.receivedAt = DebugReleaseData.date(day: 17)
        #expect(one.asks(sameAs: again))
        again.evidence.why = "Another reason."
        #expect(!one.asks(sameAs: again))
        #expect(ReleaseProposal.makeID().hasPrefix("rp-"))
        #expect(ReleaseProposal.makeID().count == 11)
    }
}
#endif
