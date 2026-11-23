//
//  ReleaseProposalDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The version card with an assistant's proposal waiting
/// (`-AtlasDebugScene <id>`), Lumen Journal 1.4 on Overview, "today" Nov
/// 16, 2026:
///
/// - `rel-proposed-submit`: before submitting, Claude Code proposes build
///   211, released right after approval, phased, standard encryption, with
///   the Mood Calendar event; Confirm opens the Submit sheet with them.
/// - `rel-proposed-release`: approved and waiting; Claude Code proposes to
///   release it now; Confirm asks first, as the card's button does.
/// - `rel-proposed-pause`: rolling out on day 3; Claude Code proposes to
///   pause over a crash; Confirm pauses it.
/// - `rel-proposed-outdated`: waiting for review, with a proposal to
///   release that no longer fits: it says why, with Dismiss only.
enum ReleaseProposalDebugScenes {
    typealias Data = DebugReleaseData

    static let ids = ["rel-proposed-submit", "rel-proposed-release", "rel-proposed-pause", "rel-proposed-outdated"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "rel-proposed-submit":
            let submission = ReleaseProposalSubmission(
                buildID: "build-211", buildNumber: "211", releaseType: ReleaseTiming.afterApproval.releaseType, isPhased: true,
                encryption: EncryptionAnswer.exempt.rawValue, eventIDs: [DebugInAppEventsData.moodID]
            )
            return scene(.prepare, proposal: proposal(
                .submit, submission: submission,
                why: "Build 211 is the one TestFlight testers used all week; 212 only bumps the build number for a test flag.",
                evidence: ["CHANGELOG.md — 1.4: Mood Calendar, iCloud sync fix", "Lumen/Info.plist — ITSAppUsesNonExemptEncryption = NO"]
            ))
        case "rel-proposed-release":
            return scene(.pending, proposal: proposal(
                .release, why: "App Review approved 1.4 this morning, and the Mood Calendar event starts on Friday: it needs 1.4 out.",
                evidence: ["get_in_app_events — Mood Calendar starts Nov 20"]
            ))
        case "rel-proposed-pause":
            return scene(.phased, proposal: proposal(
                .pausePhasedRelease, why: "Crashes doubled on day 3 (0.4% of sessions, from 0.2%), all in the new Mood Calendar.",
                evidence: ["get_analytics_crashes — 1.4 (212): 0.4% of sessions", "MoodCalendarView.swift:88 — force unwrap of an empty month"]
            ))
        case "rel-proposed-outdated":
            return scene(.waiting, proposal: proposal(
                .release, why: "App Review approved 1.4: release it so the Mood Calendar event has it.", evidence: []
            ))
        default:
            return nil
        }
    }

    /// Claude Code's proposal for Lumen 1.4, received at 10:00.
    @MainActor
    static func proposal(
        _ action: ReleaseProposal.Action, submission: ReleaseProposalSubmission? = nil, why: String, evidence: [String]
    ) -> ReleaseProposal {
        ReleaseProposal(
            id: "rp-debug-\(action.rawValue)", appID: DebugFixtures.AppID.lumen, versionID: Data.versionID, versionString: Data.versionString,
            platform: "IOS", action: action, submission: submission,
            evidence: AssistantEvidence(
                client: DebugReviewsData.client, summary: action.title(version: Data.versionString), why: why, evidence: evidence
            ),
            receivedAt: Data.date(day: 16, hour: 10)
        )
    }

    @MainActor
    private static func scene(_ phase: DebugReleasePhase, proposal: ReleaseProposal) -> AnyView {
        // Once: a view built again mustn't bring back a dismissed one.
        let store = ReleaseProposalStore.shared
        if store.proposal(id: proposal.id) == nil { store.add(proposal) }
        ReleaseDebugLaunch.pending = ReleaseDebugLaunch()
        return AnyView(DebugMainScene(
            services: ReleaseDebugScenes.services(phase), selectedAppID: DebugFixtures.AppID.lumen, section: .overview, pendingChanges: [],
            suggestions: Data.suggestions(), release: Data.store(phase)
        ))
    }
}
#endif
