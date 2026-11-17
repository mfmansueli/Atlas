//
//  ReviewReplyUndo.swift
//  Atlas
//

import Foundation

/// What Undo takes back after Send Reply: the reply just sent, and the
/// one it replaced, if any.
struct ReviewReplyUndo: Hashable, Sendable {
    var reviewID: AppReview.ID
    var sent: ReviewReply
    var previous: ReviewReply?
}
