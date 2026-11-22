//
//  AutoReplyHistoryEntry.swift
//  Atlas
//

import Foundation

/// One reply sent by itself, for History (board 58 · 5), with the rule
/// that allowed it and Undo.
struct AutoReplyHistoryEntry: Codable, Hashable, Sendable, Identifiable {
    var reviewID: AppReview.ID
    var replyID: String
    var text: String
    var rating: Int
    /// "Kenji, Japan".
    var reviewer: String
    var sentAt: Date
    /// The rule's summary when it went out.
    var rule: String
    /// Undo took it off the App Store.
    var undoneAt: Date?

    var id: String { "\(reviewID)-\(sentAt.timeIntervalSince1970)" }
}
