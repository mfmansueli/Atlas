//
//  ProductPageSuggestion.swift
//  Atlas
//

import Foundation

/// A page an assistant suggested over MCP (`propose_product_page`), with
/// what it would have and why: accepting it makes a draft page in Atlas.
/// Only suggestions with evidence Atlas can show are listed.
struct ProductPageSuggestion: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    /// "For people who want a look back at their week, not a daily habit".
    var audience: String
    /// Why, from the evidence: "Your product page test … downloads 18% better".
    var reason: String
    /// What it's based on: `analytics`, `reviews`, `keywords`, with a ref.
    var evidence: [SuggestionEvidence]
    /// The keywords, by locale, from the approved version's.
    var keywords: [String: [String]] = [:]
    /// The promotional text, by locale.
    var promotionalTexts: [String: String] = [:]
    /// What the screenshots should show first, for Autopilot.
    var screens: String = ""
    var deepLink: String = ""
    /// Who suggested it: "Claude Code".
    var source: String
    var createdAt: Date = .now

    /// "Analytics · Product Page test": the evidence pill.
    var evidenceTitle: String {
        evidence.map { item in
            let kind = switch item.kind {
            case "analytics": String(localized: "Analytics")
            case "reviews": String(localized: "Reviews")
            case "keywords": String(localized: "Keywords")
            default: item.kind.capitalized
            }
            return item.ref.isEmpty ? kind : "\(kind) · \(item.ref)"
        }
        .joined(separator: " · ")
    }

    /// The promotional text in the primary language, else any.
    func promotionalText(primary: String) -> String {
        promotionalTexts[primary] ?? promotionalTexts.sorted { $0.key < $1.key }.first?.value ?? ""
    }

    /// The keywords in the primary language, else any.
    func keywords(primary: String) -> [String] {
        keywords[primary] ?? keywords.sorted { $0.key < $1.key }.first?.value ?? []
    }
}
