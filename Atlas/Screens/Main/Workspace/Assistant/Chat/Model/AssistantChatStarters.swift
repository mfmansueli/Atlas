//
//  AssistantChatStarters.swift
//  Atlas
//

import Foundation

/// The questions an empty chat offers (board 69: they change with the
/// section): the section's own first, then two that fit anywhere.
enum AssistantChatStarters {
    static func starters(for section: AppWorkspaceSection) -> [String] {
        let anywhere = [
            String(localized: "What should I do first?", comment: "kind:button · a chat starter question"),
            String(localized: "What changed since last month?", comment: "kind:button · a chat starter question"),
        ]
        guard let own = own(for: section) else { return anywhere }
        return [own] + anywhere
    }

    private static func own(for section: AppWorkspaceSection) -> String? {
        switch section {
        case .overview: String(localized: "Will App Review reject anything?", comment: "kind:button · a chat starter question")
        case .storePage: String(localized: "Which languages need the most work?", comment: "kind:button · a chat starter question")
        case .screenshots: String(localized: "Which screenshots should I update first?", comment: "kind:button · a chat starter question")
        case .productPages: String(localized: "Which page brings the most downloads?", comment: "kind:button · a chat starter question")
        case .inAppEvents: String(localized: "When should the next event start?", comment: "kind:button · a chat starter question")
        case .nominations: String(localized: "Is this version worth nominating?", comment: "kind:button · a chat starter question")
        case .appInformation: String(localized: "Will App Review reject anything?", comment: "kind:button · a chat starter question")
        case .subscriptionPricing: String(localized: "Which countries lose the most sales?", comment: "kind:button · a chat starter question")
        case .reviews: String(localized: "What do people complain about most?", comment: "kind:button · a chat starter question")
        case .analytics: String(localized: "Where do people drop off?", comment: "kind:button · a chat starter question")
        }
    }
}
