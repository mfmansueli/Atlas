//
//  AutoReplyDraft.swift
//  Atlas
//

import Foundation

/// Reply Automatically's record of one review's reply (board 58): what
/// Claude flagged it as and where it is. The text itself is the review's
/// suggested reply in `ReviewsStore`, which the card shows with Send.
struct AutoReplyDraft: Codable, Hashable, Sendable {
    var reviewID: AppReview.ID
    var state: AutoReplyDraftState
    /// The topics Claude read in the review that always wait.
    var topics: Set<AutoReplyTopic> = []
    /// Claude wasn't sure what the review meant.
    var isUnsure = false
    var createdAt: Date
}
