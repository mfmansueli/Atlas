//
//  ProAssistantGate.swift
//  Atlas
//

import Foundation

/// What an assistant may do over MCP in Free: everything that reads, and
/// every suggestion one by one. A tool that makes something Pro's gets a
/// clear answer that it needs Pro, so the assistant says so and goes on.
enum ProAssistantGate {
    /// The Pro feature a tool belongs to; nil for the tools Free has.
    static func feature(forTool name: String) -> ProFeature? {
        switch name {
        case "propose_retention_message", "propose_retention_offer": .retention
        default: nil
        }
    }

    /// What Pro has that `tool` makes: a Pro feature's name, or the
    /// suggested replies and groups in Reviews (Free replies by hand).
    static func proName(forTool name: String) -> String? {
        if let feature = feature(forTool: name) { return feature.title }
        switch name {
        case "propose_review_replies", "propose_review_themes": return String(localized: "Suggesting replies to reviews")
        default: return nil
        }
    }

    /// The refusal for `tool` when the person is on Free; nil when it may
    /// run.
    static func refusal(forTool name: String, isPro: Bool) -> String? {
        guard !isPro, let title = proName(forTool: name) else { return nil }
        return String(localized: """
        \(title) is part of Atlas Pro, and this person is on Free, so this wasn’t queued. Tell them it needs Pro \
        (the Pro button in Atlas’s toolbar) and go on with the rest; reading and one-by-one suggestions work in Free.
        """)
    }
}
