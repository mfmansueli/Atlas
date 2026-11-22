//
//  ProductPagesAskButton.swift
//  Atlas
//

import SwiftUI

/// Suggest Pages, Ask Claude Code for Ideas and Ask for Another: starts
/// the person's assistant with the section's prompt (or copies it). Pages
/// come back with `propose_product_page`, texts with
/// `propose_product_page_texts`, and wait here as suggestions.
struct ProductPagesAskButton: View {
    enum Kind {
        /// The empty list's Ask Claude Code for Ideas.
        case ideas
        /// After a text Atlas stopped: Ask for Another.
        case another(pageName: String)
    }

    let app: StoreApp
    let kind: Kind
    let prompt: String
    let identifier: String

    var body: some View {
        ClaudeCodeAskButton(
            app: app,
            purpose: ProductPagesAskPrompt.purpose,
            prompt: prompt,
            help: { client in help(client) },
            explanation: { client in explanation(client) },
            identifier: identifier,
            title: { client in title(client) },
            subject: subject,
            done: { client in String(localized: "\(client) is done. Its suggestions are in Custom Product Pages.") }
        )
    }

    private func title(_ client: String) -> String {
        switch kind {
        case .ideas: String(localized: "Ask \(client) for Ideas")
        case .another: String(localized: "Ask for Another")
        }
    }

    private func help(_ client: String) -> String {
        switch kind {
        case .ideas: String(localized: "Ask \(client) to suggest pages from your reviews, your numbers and your keywords")
        case .another: String(localized: "Ask \(client) for a text that follows App Review’s rules")
        }
    }

    private func explanation(_ client: String) -> String {
        switch kind {
        case .ideas:
            String(localized: """
            \(client) reads \(app.name)’s pages, reviews and numbers, and suggests pages: who each is for, why, its \
            keywords and promotional text. They wait at the top of the list; accepted, each is a draft you push and submit \
            yourself.
            """)
        case let .another(pageName):
            String(localized: """
            \(client) writes another promotional text for “\(pageName)”, without prices, offers or other platforms. It waits \
            here as a suggestion.
            """)
        }
    }

    private var subject: String? {
        switch kind {
        case .ideas: String(localized: "Custom Product Pages · ideas for new pages")
        case let .another(pageName): String(localized: "Custom Product Pages · \(pageName)")
        }
    }
}
