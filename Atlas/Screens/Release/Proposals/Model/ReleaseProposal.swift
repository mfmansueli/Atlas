//
//  ReleaseProposal.swift
//  Atlas
//

import Foundation

/// What an assistant proposed for a version over MCP
/// (`propose_release_action`): submit it for review with these choices,
/// release it, pause, resume or complete its phased release, cancel its
/// submission or send it again. Nothing is sent: it waits on the Overview's
/// version card, with the assistant's reason, until the person confirms
/// it (which runs the card's own action, asking first where the card asks)
/// or dismisses it.
struct ReleaseProposal: Identifiable, Hashable, Codable, Sendable {
    /// What the assistant asks for; the raw values are the tool's names.
    enum Action: String, CaseIterable, Hashable, Codable, Sendable {
        case submit
        case release
        case pausePhasedRelease = "pause_phased_release"
        case resumePhasedRelease = "resume_phased_release"
        case completePhasedRelease = "complete_phased_release"
        case cancelSubmission = "cancel_submission"
        case resubmit

        /// The card's action it runs; nil for Submit, which opens the
        /// Submit sheet with the proposal's choices.
        var releaseAction: ReleaseAction? {
            switch self {
            case .submit: nil
            case .release: .releaseNow
            case .pausePhasedRelease: .pause
            case .resumePhasedRelease: .resume
            case .completePhasedRelease: .releaseToEveryone
            case .cancelSubmission: .cancelSubmission
            case .resubmit: .submitAgain
            }
        }

        /// The proposal a card action carries out.
        init(_ action: ReleaseAction) {
            switch action {
            case .releaseNow: self = .release
            case .pause: self = .pausePhasedRelease
            case .resume: self = .resumePhasedRelease
            case .releaseToEveryone: self = .completePhasedRelease
            case .cancelSubmission: self = .cancelSubmission
            case .submitAgain: self = .resubmit
            }
        }

        /// "Release 1.4 now", on the card.
        func title(version: String) -> String {
            switch self {
            case .submit: String(localized: "Submit \(version) for App Review")
            case .release: String(localized: "Release \(version) now")
            case .pausePhasedRelease: String(localized: "Pause the phased release of \(version)")
            case .resumePhasedRelease: String(localized: "Resume the phased release of \(version)")
            case .completePhasedRelease: String(localized: "Release \(version) to everyone now")
            case .cancelSubmission: String(localized: "Take \(version) back from App Review")
            case .resubmit: String(localized: "Send \(version) back to App Review")
            }
        }

        /// The banner's Confirm. "…" where something follows: the card's
        /// own question, or the Submit sheet.
        func confirmTitle(version: String) -> String {
            switch self {
            case .submit: String(localized: "Review in Submit…")
            case .release: String(localized: "Release \(version) Now…")
            case .pausePhasedRelease: String(localized: "Pause Phased Release")
            case .resumePhasedRelease: String(localized: "Resume Phased Release")
            case .completePhasedRelease: String(localized: "Release to Everyone…")
            case .cancelSubmission: String(localized: "Cancel Submission…")
            case .resubmit: String(localized: "Submit Again")
            }
        }
    }

    /// Where it stands. Only `pending` shows on the card.
    enum Status: String, Hashable, Codable, Sendable {
        case pending
        /// The person confirmed it and the action went through.
        case confirmed
        case dismissed
        /// Taken back by the assistant (`withdraw_release_action`).
        case withdrawn
        /// The same assistant proposed something else for the version.
        case replaced
    }

    /// "rp-3f9a1c2e".
    var id: String
    var appID: StoreApp.ID
    /// The version it's about, as `get_release` read it.
    var versionID: String
    var versionString: String
    var platform: String?
    var action: Action
    /// Submit's choices; nil for the other actions.
    var submission: ReleaseProposalSubmission?
    /// Who proposed it, why, and what it found.
    var evidence: AssistantEvidence
    var receivedAt: Date
    var status = Status.pending
    var resolvedAt: Date?

    /// e.g. "Claude Code".
    var client: String { evidence.client }

    var isPending: Bool { status == .pending }

    /// "Release 1.4 now".
    var title: String { action.title(version: versionString) }

    /// The same request, whoever sent it and when: proposing it again
    /// changes nothing.
    func asks(sameAs other: ReleaseProposal) -> Bool {
        appID == other.appID && versionID == other.versionID && action == other.action && submission == other.submission
            && evidence.why == other.evidence.why && evidence.evidence == other.evidence.evidence
    }

    /// A new id: "rp-" and 8 hex digits.
    static func makeID() -> String {
        "rp-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    }
}
