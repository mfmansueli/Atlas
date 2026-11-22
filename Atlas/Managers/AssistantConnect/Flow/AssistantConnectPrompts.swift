//
//  AssistantConnectPrompts.swift
//  Atlas
//

import Foundation

/// What Connect asks an assistant: the hello, the first suggestion, and
/// the things to ask next.
enum AssistantConnectPrompts {
    /// Claude Code's hello, its one call after connecting: what it sees
    /// in Atlas, what it read in the project, and an offer, without
    /// proposing anything.
    static func hello(appName: String, readsProject: Bool) -> String {
        if readsProject {
            return String(localized: """
            Read \(appName) with the atlas tools and the project folder, and introduce yourself in three short sentences: what \
            you see in Atlas (version, languages, subscriptions), what you read in the project that the App Store page doesn’t \
            say yet, and one thing you could suggest. Plain words, no lists, and don’t propose anything yet.
            """)
        }
        return String(localized: """
        Read \(appName) with the atlas tools, and introduce yourself in three short sentences: what you see in Atlas (version, \
        languages, subscriptions), and one thing you could suggest. Plain words, no lists, and don’t propose anything yet.
        """)
    }

    /// The same, for an assistant Atlas can't ask: the person pastes it.
    static func pastedHello(appName: String) -> String {
        String(localized: "Read \(appName) with the atlas tools and introduce yourself in three short sentences.")
    }

    /// "Suggest a better subtitle for Lumen Journal", as the row says it.
    static func subtitleQuestion(appName: String) -> String {
        String(localized: "Suggest a better subtitle for \(appName)")
    }

    /// Send a Test Suggestion and Ask for a First Suggestion.
    static func testSuggestion(appName: String) -> String {
        String(localized: """
        Suggest a better subtitle for \(appName) in its primary language with Atlas’s suggest_fields tool, read from the store \
        page. Say in its reason that it’s a test sent from Settings. Propose nothing else.
        """)
    }

    /// Three things to ask, in the person's own words.
    static var thingsToAsk: [String] {
        [
            String(localized: "“Translate my page to Polish”"),
            String(localized: "“Write What’s New for the next version”"),
            String(localized: "“Suggest prices for Brazil”"),
        ]
    }
}
