//
//  AssistantChatSuggestions.swift
//  Atlas
//

import Foundation

/// What one chat answer suggested: the calls Atlas logged as Suggested
/// while its run worked, and the section most of them wait in. The chat
/// shows them as one card with “Show in Pricing” (board 69: changes come
/// back as suggestion cards, in the chat and in their section).
struct AssistantChatSuggestions: Hashable, Sendable {
    /// What each suggestion is about, without the app's name:
    /// “de-DE · Subtitle”.
    var targets: [String]
    /// Where they wait; nil when Atlas can't tell from the tools.
    var section: AppWorkspaceSection?

    var count: Int { targets.count }

    /// The suggestions logged between `start` and `end` for `appName`; nil
    /// when there were none.
    static func make(from log: [MCPLogEntry], appName: String, start: Date, end: Date) -> AssistantChatSuggestions? {
        let proposed = log.filter { entry in
            entry.outcome == .proposed && entry.date >= start && entry.date <= end && entry.target.hasPrefix(appName)
        }
        guard !proposed.isEmpty else { return nil }
        let sections = proposed.compactMap { section(forTool: $0.tool) }
        // The section most of them wait in.
        let counts = Dictionary(sections.map { ($0, 1) }, uniquingKeysWith: +)
        let section = sections.first { counts[$0] == counts.values.max() }
        return AssistantChatSuggestions(targets: proposed.map { target($0.target, appName: appName) }, section: section)
    }

    /// “2 suggestions in Pricing”: the card's title.
    var title: String {
        if count == 1 {
            guard let section else { return String(localized: "1 suggestion", comment: "kind:title · a chat answer's suggestion card") }
            return String(localized: "1 suggestion in \(section.title)", comment: "kind:title · a chat answer's suggestion card")
        }
        guard let section else {
            return String(localized: "\(count) suggestions", comment: "kind:title · a chat answer's suggestion card, no section known")
        }
        return String(localized: "\(count) suggestions in \(section.title)", comment: "kind:title · a chat answer's suggestion card")
    }

    /// The first two targets, then how many more: the card's why.
    var why: String {
        let shown = targets.prefix(2).joined(separator: ", ")
        let more = count - min(count, 2)
        guard more > 0 else { return shown }
        return String(localized: "\(shown) and \(more) more", comment: "kind:why · a chat answer's suggestion card")
    }

    /// Where a tool's suggestion waits, from its name.
    static func section(forTool tool: String) -> AppWorkspaceSection? {
        let sections: [(prefix: String, section: AppWorkspaceSection)] = [
            ("propose_page_", .productPages), ("propose_product_page", .productPages), ("request_page_", .productPages),
            ("propose_event", .inAppEvents), ("propose_in_app_event", .inAppEvents), ("withdraw_event", .inAppEvents),
            ("propose_nomination", .nominations),
            ("propose_review_", .reviews),
            ("add_finding", .analytics),
            ("propose_prices", .subscriptionPricing), ("propose_app_price", .subscriptionPricing),
            ("propose_availability", .subscriptionPricing), ("propose_subscription", .subscriptionPricing),
            ("propose_introductory_offer", .subscriptionPricing), ("propose_promotional_offer", .subscriptionPricing),
            ("propose_offer_code", .subscriptionPricing), ("propose_win_back_offer", .subscriptionPricing),
            ("propose_in_app_purchase", .subscriptionPricing), ("propose_retention_", .subscriptionPricing),
            ("propose_purchase_review_screenshot", .subscriptionPricing),
            ("propose_captions", .screenshots), ("propose_screenshot", .screenshots), ("propose_screens", .screenshots),
            ("propose_template", .screenshots), ("propose_direction", .screenshots), ("request_recapture", .screenshots),
            ("propose_artwork", .screenshots), ("revise_", .screenshots),
            ("propose_age_rating", .appInformation), ("propose_privacy_answers", .appInformation),
            ("propose_compliance_answers", .appInformation), ("propose_export_compliance", .appInformation),
            ("answer_app_questions", .appInformation),
            ("propose_listing_text", .storePage), ("suggest_fields", .storePage), ("propose_in_app_texts", .storePage),
            ("propose_in_app_review_note", .storePage),
            ("propose_app_version", .overview), ("propose_release_action", .overview),
        ]
        return sections.first { tool.hasPrefix($0.prefix) }?.section
    }

    /// “Lumen Journal · de-DE · Subtitle” → “de-DE · Subtitle”.
    private static func target(_ target: String, appName: String) -> String {
        let rest = target.dropFirst(appName.count).drop { $0 == " " || $0 == "·" }
        return rest.isEmpty ? target : String(rest)
    }
}
