//
//  ReleaseProposalRules.swift
//  Atlas
//

import Foundation

/// What can be done with a version in each state, as the version card
/// offers it: submit before review (or after a rejection), cancel while it
/// waits for review, send a rejected submission back, release one approved
/// and waiting for the person, and pause, resume or complete a phased
/// release. `propose_release_action` refuses anything else with why, and
/// the card shows a proposal that no longer fits as out of date.
enum ReleaseProposalRules {
    /// The actions the card offers for `status` now.
    static func possibleActions(in status: ReleaseStatus) -> [ReleaseProposal.Action] {
        ReleaseProposal.Action.allCases.filter { problem($0, in: status) == nil }
    }

    /// Why `action` can't be done in `status`, with what can; nil when it
    /// can.
    static func problem(_ action: ReleaseProposal.Action, in status: ReleaseStatus) -> String? {
        guard let why = reason(action, in: status) else { return nil }
        let others = ReleaseProposal.Action.allCases.filter { $0 != action && reason($0, in: status) == nil }
        let next = others.isEmpty
            ? waitNote(for: status.phase)
            : String(localized: "Possible now: \(others.map(\.rawValue).formatted(.list(type: .or))).")
        return "\(why) \(next)"
    }

    /// Why not, without what's possible instead.
    private static func reason(_ action: ReleaseProposal.Action, in status: ReleaseStatus) -> String? {
        let state = String(localized: "\(status.version.versionString) is \(status.phase.pillTitle)")
        switch action {
        case .submit: return submitReason(status, state: state)
        case .release: return releaseReason(status, state: state)
        case .pausePhasedRelease, .resumePhasedRelease, .completePhasedRelease: return phasedReason(action, status, state: state)
        case .cancelSubmission, .resubmit: return submissionReason(action, status, state: state)
        }
    }

    private static func submitReason(_ status: ReleaseStatus, state: String) -> String? {
        switch status.phase {
        case .prepare, .rejected: nil
        case .live: String(localized: "\(status.version.versionString) is on the App Store already; a new release needs a new version (propose_app_version).")
        default: String(localized: "\(state): it was submitted already.")
        }
    }

    private static func releaseReason(_ status: ReleaseStatus, state: String) -> String? {
        switch status.phase {
        case .pendingDeveloperRelease: nil
        case .pendingAppleRelease: String(localized: "\(state): Apple releases it automatically.")
        default: String(localized: "\(state). Only a version App Review approved and that waits for the person (Pending Developer Release) can be released.")
        }
    }

    private static func phasedReason(_ action: ReleaseProposal.Action, _ status: ReleaseStatus, state: String) -> String? {
        let isPaused = status.phased?.state == .paused
        let isActive = status.phased?.state == .active
        let rollingOut = String(localized: "\(state): only a phased release that’s rolling out can be paused.")
        let notPaused = String(localized: "\(state): only a paused phased release can be resumed.")
        let notRolling = String(localized: "\(state): only a phased release that’s rolling out or paused can go to everyone.")
        guard case .phased = status.phase else {
            return action == .pausePhasedRelease ? rollingOut : action == .resumePhasedRelease ? notPaused : notRolling
        }
        switch action {
        case .pausePhasedRelease where isPaused: return String(localized: "\(status.version.versionString)’s phased release is already paused.")
        case .pausePhasedRelease: return isActive ? nil : rollingOut
        case .resumePhasedRelease: return isPaused ? nil : notPaused
        default: return isPaused || isActive ? nil : notRolling
        }
    }

    private static func submissionReason(_ action: ReleaseProposal.Action, _ status: ReleaseStatus, state: String) -> String? {
        let phase = status.phase
        if action == .cancelSubmission {
            if phase == .waitingForReview, status.submission?.canCancel == true { return nil }
            if phase == .inReview { return String(localized: "\(state): App Review has started; it can’t be canceled.") }
            return String(localized: "\(state): only a submission waiting for review can be canceled.")
        }
        if phase == .rejected, status.submission?.hasUnresolvedIssues == true { return nil }
        if phase == .rejected {
            return String(localized: "App Review’s submission of \(status.version.versionString) isn’t open anymore: propose submit to send it in a new one.")
        }
        return String(localized: "\(state): only a version App Review sent back can be sent again.")
    }

    /// When nothing can be done.
    private static func waitNote(for phase: ReleasePhase) -> String {
        switch phase {
        case .inReview: String(localized: "Nothing can be done until App Review finishes.")
        case .pendingAppleRelease: String(localized: "Nothing to do: Apple releases it.")
        case .live: String(localized: "Nothing to do: everyone gets it.")
        default: String(localized: "Nothing can be done with it now.")
        }
    }
}
