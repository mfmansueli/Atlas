//
//  AutoReplyTone.swift
//  Atlas
//

import Foundation

/// How Claude writes the automatic replies (board 58), with the settings'
/// example reply, which changes with it.
enum AutoReplyTone: String, Codable, CaseIterable, Hashable, Sendable {
    case warm
    case brief
    case formal

    var title: String {
        switch self {
        case .warm: String(localized: "Warm")
        case .brief: String(localized: "Brief")
        case .formal: String(localized: "Formal")
        }
    }

    /// What the prompt asks Claude for.
    var instruction: String {
        switch self {
        case .warm: "warm and personal, two or three sentences"
        case .brief: "brief, one or two sentences"
        case .formal: "formal and courteous, two or three sentences"
        }
    }

    /// A reply to a 5★ review that says the weekly recap helps, in this
    /// tone, signed with `signature` when there is one.
    func example(appName: String, signature: String) -> String {
        let body = switch self {
        case .warm:
            String(localized: "Thank you so much! It means a lot that the weekly recap helps you look back. Happy writing with \(appName).")
        case .brief:
            String(localized: "Thanks for the kind words. Glad the weekly recap helps!")
        case .formal:
            String(
                localized: "Thank you for your review. We are pleased that the weekly recap is useful to you, and we appreciate you taking the time to write."
            )
        }
        let name = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? body : "\(body)\n— \(name)"
    }
}
