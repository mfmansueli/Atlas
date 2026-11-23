//
//  ReleaseProposalBadgeTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A release action an assistant proposed is counted where the person
/// looks: on the Overview in the sidebar and the section menu (the version
/// card it waits on is there), in the app's total, and as a line under the
/// menu bar's "Needs you" that opens the version card.
@MainActor
@Suite("Release proposals · badges and Needs you")
struct ReleaseProposalBadgeTests {
    private let lumen = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen }!

    private func proposal(id: String, client: String = "Claude Code", platform: String = "IOS") -> ReleaseProposal {
        ReleaseProposal(
            id: id, appID: DebugFixtures.AppID.lumen, versionID: DebugReleaseData.versionID, versionString: "1.4", platform: platform,
            action: .release,
            evidence: AssistantEvidence(client: client, summary: "", why: "Approved this morning.", evidence: []),
            receivedAt: DebugReleaseData.today
        )
    }

    @Test func aWaitingProposalCountsOnTheOverview() {
        let counts = SectionBadgeCounts(
            appID: lumen.id, suggestions: FieldSuggestionStore(), extras: SectionBadgeCounts.Extras(releaseProposals: 1)
        )
        #expect(counts.count(for: .overview) == 1)
        #expect(counts.text(for: .overview) == "1")
        #expect(counts.total == 1)
        #expect(counts.accessibilityText(for: .overview) == "Overview, 1 suggestion to review")
        #expect(SectionBadgeCounts(appID: lumen.id, suggestions: FieldSuggestionStore()).count(for: .overview) == 0)
    }

    @Test func eachWaitingProposalIsANeedsYouLineToTheVersionCard() {
        let facts = BackgroundAppFacts(
            appID: lumen.id, appName: lumen.name, openSuggestions: 2,
            releaseProposals: [BackgroundAppFacts.ReleaseProposalFact(client: "Claude Code", title: "Release 1.4 now")]
        )
        let needs = BackgroundNeedsBuilder.needs(for: [facts], namesApps: false)
        #expect(needs.map(\.title) == ["Claude Code suggests: Release 1.4 now", "2 suggestions to review"])
        #expect(needs.first?.detail == "Confirm or dismiss it on the version card")
        #expect(needs.first?.destination == .version(appID: lumen.id))
        #expect(needs.first?.isSuggestion == true)

        let named = BackgroundNeedsBuilder.needs(for: [facts], namesApps: true)
        #expect(named.first?.detail == "\(lumen.name) · Confirm or dismiss it on the version card")
    }

    @Test func backgroundWorkReadsTheWaitingOnesOnly() {
        let store = ReleaseProposalStore()
        store.add(proposal(id: "rp-1"))
        store.add(proposal(id: "rp-2", client: "Codex", platform: "MAC_OS"))
        store.add(proposal(id: "rp-3", client: "Cursor", platform: "VISION_OS"))
        store.resolve("rp-3", as: .dismissed)
        let work = BackgroundWork(
            push: PushController(queue: ChangeQueue(), history: PushHistory()),
            changes: ChangeQueue(),
            suggestions: FieldSuggestionStore(),
            preferences: AppPreferences(defaults: nil),
            autopilot: AutopilotCenter(),
            reviews: ReviewsStore(),
            releases: ReleaseStore(),
            releaseProposals: store,
            analytics: AnalyticsStore(),
            artwork: EventArtworkStudio(),
            pageShots: PageShotsStudio(),
            defaults: nil,
            now: { DebugReleaseData.today }
        )
        work.library = [lumen]
        let lines = work.needs.filter { $0.id.hasPrefix("release-proposal-") }
        #expect(lines.map(\.title) == ["Claude Code suggests: Release 1.4 now", "Codex suggests: Release 1.4 now"])
    }
}
#endif
