//
//  AutoReplyDraftState.swift
//  Atlas
//

import Foundation

/// Where one automatic reply is (board 58).
enum AutoReplyDraftState: Codable, Hashable, Sendable {
    /// Allowed: it goes out by itself at `sendAt`, unless Don't Send.
    case scheduled(sendAt: Date)
    /// It waits for the person, and why: “it mentions a crash”.
    case needsYou(reason: String)
    /// Draft and tell me: written, the person was told, nothing goes out.
    case drafted
    /// Sent by itself; Undo takes it off the App Store.
    case sent(replyID: String, sentAt: Date)
    /// Don't Send: it stays a suggestion the person can send.
    case held

    var isScheduled: Bool {
        if case .scheduled = self { return true }
        return false
    }

    var needsYou: Bool {
        if case .needsYou = self { return true }
        return false
    }

    var sendAt: Date? {
        if case let .scheduled(sendAt) = self { return sendAt }
        return nil
    }
}
