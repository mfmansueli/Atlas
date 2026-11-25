//
//  ReleaseViewModel+Proposals.swift
//  Atlas
//

import Foundation

// What an assistant proposed for the version over MCP, on the card: the
// one waiting, whether it still fits the version, and Confirm (the
// card's own action, asking first where the card asks; for Submit, the
// sheet with the proposal's choices) and Dismiss. Nothing is sent until
// the person confirms.
extension ReleaseViewModel {
    /// The newest proposal waiting for this app's version on its platform.
    var waitingProposal: ReleaseProposal? {
        guard let status else { return nil }
        return proposals.pending(for: app.id).last { proposal in
            proposal.platform == nil || status.version.platform == nil || proposal.platform == status.version.platform
        }
    }

    /// Why `proposal` can't be confirmed as the version is now; nil when
    /// it can.
    func proposalProblem(_ proposal: ReleaseProposal) -> String? {
        guard let status else { return String(localized: "The version hasn’t been read yet.") }
        guard proposal.versionID == status.version.id else {
            if proposal.versionString == status.version.versionString {
                return String(localized: "It was for another \(proposal.versionString) than the one now.")
            }
            return String(localized: "It was for \(proposal.versionString); the version now is \(status.version.versionString).")
        }
        return ReleaseProposalRules.problem(proposal.action, in: status)
    }

    /// What the card lists under the title: Submit's choices.
    func proposalLines(_ proposal: ReleaseProposal) -> [String] {
        guard let submission = proposal.submission else { return [] }
        return submission.lines(version: proposal.versionString) { id in
            events.first { $0.id == id }.map(Self.displayName(of:)) ?? id
        }
    }

    /// Confirm on the card. Submit puts the proposal's choices in the
    /// Submit sheet and returns true for the card to open it; the other
    /// actions run the card's own button (asking first when it asks).
    /// The proposal is settled once the action went through.
    @discardableResult
    func confirmProposal(_ proposal: ReleaseProposal) -> Bool {
        guard proposalProblem(proposal) == nil else { return false }
        if let action = proposal.action.releaseAction {
            request(action)
            return false
        }
        if let submission = proposal.submission { apply(submission) }
        return true
    }

    /// Dismiss on the card.
    func dismissProposal(_ proposal: ReleaseProposal) {
        proposals.resolve(proposal.id, as: .dismissed)
    }

    /// The Submit sheet's choices as proposed: a build that can't be
    /// chosen anymore, or events no longer offered, are left as they were.
    func apply(_ submission: ReleaseProposalSubmission) {
        if status?.builds.contains(where: { $0.id == submission.buildID && $0.isSelectable }) == true {
            options.buildID = submission.buildID
        }
        options.timing = submission.timing.kind
        if let date = submission.timing.date { options.releaseDate = date }
        options.isPhased = submission.isPhased
        if let answer = submission.encryptionAnswer ?? knownEncryption { options.encryption = answer }
        options.pushesChanges = submission.pushesChanges ?? true
        if let ids = submission.eventIDs {
            let offered = offeredEvents.map(\.id)
            options.eventIDs = Set(ids).intersection(offered)
            store.setEventIDs(offered.filter(options.eventIDs.contains), for: app.id)
        }
    }
}
