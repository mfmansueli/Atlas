//
//  AutoReplyMode.swift
//  Atlas
//

import Foundation

/// What Reply Automatically does with a reply Claude wrote (board 58).
enum AutoReplyMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// Draft a reply and tell me: nothing is sent until Send.
    case draftAndTell
    /// Send the ones I allow by themselves, after the wait; the rest wait.
    case sendAllowed

    var title: String {
        switch self {
        case .draftAndTell: String(localized: "Draft a reply and tell me")
        case .sendAllowed: String(localized: "Send the ones I allow by themselves")
        }
    }

    var detail: String {
        switch self {
        case .draftAndTell: String(localized: "Nothing is sent until you press Send.")
        case .sendAllowed: String(localized: "Allowed replies go out after the wait. Everything else waits for you.")
        }
    }
}
