//
//  NominationActionRequest.swift
//  Atlas
//

import Foundation

/// An assistant asking to submit a ready draft or archive a submitted
/// nomination (`propose_nomination_submit`, `propose_nomination_archive`).
/// It waits on the nomination; Accept opens the same confirmation sheet the
/// person's own Submit… or Archive… does. The assistant never sends it.
struct NominationActionRequest: Identifiable, Hashable, Codable, Sendable {
    enum Action: String, Hashable, Codable, Sendable {
        case submit
        case archive
    }

    var id: String
    var nominationID: String
    var action: Action
    var evidence: AssistantEvidence
    var receivedAt: Date

    var client: String { evidence.client }
}
