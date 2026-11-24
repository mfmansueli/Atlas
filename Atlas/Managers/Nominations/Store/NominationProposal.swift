//
//  NominationProposal.swift
//  Atlas
//

import Foundation

/// An assistant's nomination (`propose_nomination`): a new one, or changes
/// to a draft (`nominationID`). It isn't a draft and isn't in Review & Push
/// until the person accepts it; then it becomes one, marked "Suggested by
/// <client>", and its Create or Update row waits in Review & Push.
struct NominationProposal: Identifiable, Hashable, Codable, Sendable {
    var id: String
    /// The draft it changes; nil for a new nomination.
    var nominationID: String?
    var content: NominationContent
    var evidence: AssistantEvidence
    var receivedAt: Date

    var client: String { evidence.client }
    var isNew: Bool { nominationID == nil }
}
