//
//  NominationsArchive.swift
//  Atlas
//

import Foundation

/// One app's nominations as this Mac keeps them (`NominationsStore`):
/// drafts not in App Store Connect yet, edits to drafts that are, what
/// assistants suggested, and the Apple refusal a draft got last.
struct NominationsArchive: Hashable, Codable, Sendable {
    /// Drafts on this Mac (`local-…` IDs).
    var drafts: [Nomination] = []
    /// Changed fields of drafts App Store Connect has, by ID, until they're
    /// pushed.
    var edits: [String: NominationContent] = [:]
    /// When each nomination's Create or Update row was last put in Review &
    /// Push: once the row is gone, a draft on this Mac that App Store Connect
    /// has by then (same name) is replaced by it.
    var queuedAt: [String: Date] = [:]
    var proposals: [NominationProposal] = []
    var actionRequests: [NominationActionRequest] = []
    /// Built-in suggestions the person dismissed, by `nominationID.field`.
    var dismissedBuiltIns: Set<String> = []
    /// Apple's refusal of a push, by nomination: what happened and its
    /// own words for Details.
    var refusals: [String: NominationRefusal] = [:]
}
