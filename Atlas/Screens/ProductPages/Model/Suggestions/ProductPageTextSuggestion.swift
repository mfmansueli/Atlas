//
//  ProductPageTextSuggestion.swift
//  Atlas
//

import Foundation

/// A promotional text an assistant suggested for one language of a page
/// (`propose_product_page_texts`). One App Review would reject (a price,
/// "free", a discount, another platform) is kept to show why, with its
/// phrases marked, and can't be accepted.
struct ProductPageTextSuggestion: Identifiable, Codable, Hashable, Sendable {
    var pageID: ProductPage.ID
    var locale: String
    var text: String
    /// "From your English text. German reviews say “gesperrt” for the lock."
    var reason: String
    /// "Claude Code".
    var source: String
    /// Why Atlas didn't offer it: the rules it breaks; empty when it can be
    /// accepted.
    var refusal: String = ""
    /// The phrases that break them, to mark in the text.
    var refusedPhrases: [String] = []
    var createdAt: Date = .now
    /// What it's based on, when the assistant said (`analytics`, `reviews`,
    /// `keywords`, with a ref). Optional, so suggestions kept before it
    /// still read.
    var evidence: [SuggestionEvidence]?

    var id: String { "\(pageID).\(locale)" }

    var isRefused: Bool { !refusal.isEmpty }
}
