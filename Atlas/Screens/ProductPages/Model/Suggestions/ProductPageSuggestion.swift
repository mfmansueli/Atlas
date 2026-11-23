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
    /// What the page starts from (`propose_product_page`'s `startFrom`);
    /// nil is the default page. Optional, so suggestions kept before it
    /// still read.
    var start: ProductPageStart?
    /// The promotional texts Atlas stopped because App Review would reject
    /// them, kept to show why ("Not offered") and left out of
    /// `promotionalTexts`, so accepting never puts them in the draft. Each
    /// has this suggestion's ID as its page; the draft made from it takes
    /// them as its own (`ProductPagesStore.save`). Optional, like `start`.
    var notOfferedTexts: [ProductPageTextSuggestion]?
    /// Details and how sure, beside the reason; nil in suggestions kept
    /// before.
    var layers: SuggestionLayers?

    /// "Analytics · Brazil: 4% open the page": one pill for each piece of
    /// evidence, so several wrap instead of making one pill wider than the
    /// row.
    var evidenceTitles: [String] {
        evidence.map { item in
            let kind = switch item.kind {
            case "analytics": String(localized: "Analytics")
            case "reviews": String(localized: "Reviews")
            case "keywords": String(localized: "Keywords")
            default: item.kind.capitalized
            }
            return item.ref.isEmpty ? kind : "\(kind) · \(item.ref)"
        }
    }

    /// Every piece of evidence in one line.
    var evidenceTitle: String {
        evidenceTitles.joined(separator: " · ")
    }

    /// The languages it chooses keywords in, the primary one first.
    func keywordLocales(primary: String) -> [String] {
        let chosen = keywords.filter { !$0.value.isEmpty }.keys
        return chosen.sorted { ($0 == primary ? 0 : 1, $0) < ($1 == primary ? 0 : 1, $1) }
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
