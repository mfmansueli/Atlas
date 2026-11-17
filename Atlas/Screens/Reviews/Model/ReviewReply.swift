//
//  ReviewReply.swift
//  Atlas
//

import Foundation

/// The developer's reply under a review. The App Store shows one per
/// review; sending another replaces it.
struct ReviewReply: Identifiable, Hashable, Codable, Sendable {
    /// The `customerReviewResponses` id; "" for one that never reached
    /// Apple (a DEBUG scene's).
    var id: String
    var text: String
    /// When it was last changed.
    var date: Date
    /// Apple has it but doesn't show it yet (`PENDING_PUBLISH`).
    var isPending = false
}
