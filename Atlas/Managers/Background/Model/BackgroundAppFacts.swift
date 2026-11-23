//
//  BackgroundAppFacts.swift
//  Atlas
//

import Foundation

/// What waits on the person in one app, read from the stores that keep
/// it (Autopilot, suggestions, releases and their proposals, reviews,
/// Analytics), so
/// `BackgroundNeedsBuilder` can word the menu bar's "Needs you" lines
/// without reaching into them.
struct BackgroundAppFacts: Hashable, Sendable {
    var appID: StoreApp.ID
    var appName: String
    /// The Autopilot turn the app's run waits on, if any.
    var autopilotTurn: AutopilotTurn?
    /// Suggestions shown in the app and not yet accepted or dismissed.
    var openSuggestions = 0
    /// "1.4" when that version is approved and waits for the person to
    /// release it.
    var approvedVersion: String?
    /// Reviews with a suggested reply waiting.
    var reviewReplies = 0
    /// Reviews Reply Automatically left for the person (board 58).
    var autoReplyNeeds = 0
    /// Analytics findings the person hasn't seen.
    var newFindings = 0
    /// The first of them, for the line's detail.
    var firstFindingTitle: String?
    /// "Version 1.4 crashes 3.2× as often as 1.3…" while the newest version
    /// crashes clearly more (Analytics → Stability).
    var crashHeadline: String?
    /// Events whose artwork concepts are ready behind a hidden sheet.
    var readyArtwork: [ReadyArtwork] = []
    /// Release actions an assistant proposed, waiting on the version card.
    var releaseProposals: [ReleaseProposalFact] = []

    struct ReadyArtwork: Hashable, Sendable {
        var eventID: InAppEvent.ID
        var eventName: String
        var count: Int
    }

    struct ReleaseProposalFact: Hashable, Sendable {
        /// e.g. "Claude Code".
        var client: String
        /// "Release 1.4 now".
        var title: String
    }
}
