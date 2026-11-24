//
//  SettingsPane.swift
//  Atlas
//

import Foundation

/// Settings' panes (board 48), in the sidebar's order. Nine no longer fit
/// as toolbar tabs, and a sidebar can be searched: each pane lists the
/// words on it.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case accounts
    case assistants
    case suggestions
    case pricing
    case screenshots
    case notifications
    case pro
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .accounts: String(localized: "Accounts")
        case .assistants: String(localized: "AI Assistants")
        case .suggestions: String(localized: "Suggestions")
        case .pricing: String(localized: "Pricing")
        case .screenshots: String(localized: "Screenshots")
        case .notifications: String(localized: "Notifications")
        case .pro: String(localized: "Atlas Pro")
        case .privacy: String(localized: "Privacy & Data")
        }
    }

    /// One line under the pane's title.
    var subtitle: String {
        switch self {
        case .general: String(localized: "How Atlas looks, where it lives, and how careful it is before pushing.")
        case .accounts: String(localized: "The App Store Connect keys Atlas uses. They stay in this Mac’s Keychain.")
        case .assistants: String(localized: "Where suggestions come from, and what an assistant may and may not do.")
        case .suggestions: String(localized: "How Atlas writes, what it checks by itself, and what it never accepts for you.")
        case .pricing: String(localized: "Defaults for new apps and for prices by country.")
        case .screenshots: String(localized: "What event artwork from Claude starts with.")
        case .notifications: String(localized: "What Atlas tells you about while you’re doing something else.")
        case .pro: String(localized: "Your plan.")
        case .privacy: String(localized: "What leaves this Mac, and what Atlas keeps on it.")
        }
    }

    /// The pane's SF Symbol and system colour in the sidebar (README —
    /// Design system §13, board 48): AI Assistants is the one purple, because
    /// it is the AI.
    var style: SectionStyle {
        switch self {
        case .general: .settingsGeneral
        case .accounts: .settingsAccounts
        case .assistants: .settingsAssistants
        case .suggestions: .settingsSuggestions
        case .pricing: .settingsPricing
        case .screenshots: .settingsScreenshots
        case .notifications: .settingsNotifications
        case .pro: .settingsPro
        case .privacy: .settingsPrivacy
        }
    }

    var systemImage: String { style.symbol }

    /// The words on the pane that search finds it by, besides its title.
    var searchWords: [String] {
        switch self {
        case .general:
            ["appearance", "dark", "light", "menu bar", "dock", "login", "keep running", "animate", "check", "hour", "confirm",
             "push", "discard", "price increases"]
        case .accounts:
            ["key", "keys", "app store connect", "issuer", "keychain", "remove", "test connection", "vendor number", "sales",
             "analytics", "reports", "team"]
        case .assistants:
            ["assistant", "mcp", "claude code", "cursor", "api key", "anthropic", "openai", "gemini", "server", "pair", "revoke",
             "claude design", "design project", "activity", "built-in"]
        case .suggestions:
            ["source language", "tone", "never translated", "glossary", "checks", "keywords", "repeated", "accept all",
             "accept", "translate", "privacy", "age rating", "compliance"]
        case .pricing:
            ["pricing mode", "sales data", "base country", "rounding", "world bank", "purchasing power", "strength",
             "lower prices", "lowest", "highest", "raise", "price data", "commission", "proceeds", "small business"]
        case .screenshots: ["artwork", "event", "claude design", "words", "moving", "motion", "loop"]
        case .notifications: ["notifications", "sound", "dot", "badge", "dock", "app review", "status", "push", "reviews", "analytics"]
        case .pro: ["pro", "free", "plan", "subscription", "renew", "restore", "purchase", "redeem", "code"]
        case .privacy: ["privacy", "data", "keychain", "apple", "provider", "activity", "export", "remove", "delete", "reports"]
        }
    }

    /// Whether `query` (already lowercased and trimmed) is on this pane.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return title.lowercased().contains(query) || subtitle.lowercased().contains(query)
            || searchWords.contains { $0.contains(query) }
    }
}
