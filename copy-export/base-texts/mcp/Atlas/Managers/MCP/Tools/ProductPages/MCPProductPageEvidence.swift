//
//  MCPProductPageEvidence.swift
//  Atlas
//

import Foundation

/// The product page tools' `evidence`: what a suggestion is based on, each
/// `{source, detail}`, kept as `SuggestionEvidence` (the suggestion's pill,
/// "Analytics · Product Page test"). Only what Atlas can show the person
/// counts: its Analytics numbers, the reviews it read, and the approved
/// version's keywords. A suggested page without any isn't listed, so it's
/// refused.
@MainActor
enum MCPProductPageEvidence {
    /// The sources, as `SuggestionEvidence.kind`.
    static let sources = ["analytics", "reviews", "keywords"]
    /// The pill's label after the source.
    static let detailLimit = 60

    /// The schema of one item.
    static let itemSchema: JSONValue = MCPToolDefinition.schema(
        [
            "source": ["type": "string", "enum": .array(sources.map(JSONValue.string)), "description": "Where it comes from."],
            "detail": MCPToolDefinition.string("""
            The pill's label, ≤60 characters, with the number that points to this page, e.g. “Brazil: 4% open the page”, \
            “Search: 96% of impressions”, “23 reviews say gratitude”, “gratitude in all 14 languages”.
            """),
        ],
        required: ["source"]
    )

    /// `evidence` as one object or a list of them; none when it's left out.
    static func read(_ value: JSONValue?) throws -> [SuggestionEvidence] {
        guard let value, !value.isNull else { return [] }
        let items = value.arrayValue ?? [value]
        return try items.map { item in
            guard let object = item.objectValue, let source = object["source"]?.stringValue else {
                throw MCPToolError.invalidArgument(name: "evidence", expected: String(localized: "{source, detail} objects"))
            }
            let detail = (object["detail"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return SuggestionEvidence(kind: kind(source), ref: detail)
        }
    }

    /// "review", "Reviews" → `reviews`; anything else as written, for the
    /// refusal to name.
    private static func kind(_ source: String) -> String {
        let key = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "analytics", "productpagetest", "product page test": return "analytics"
        case "reviews", "review": return "reviews"
        case "keywords", "keyword", "approvedkeywords": return "keywords"
        default: return key
        }
    }

    /// What's wrong with it, each saying how to fix it; nothing when Atlas
    /// can show all of it. `keywordsChosen` is whether the suggestion has
    /// keywords from the approved version.
    static func problems(
        _ evidence: [SuggestionEvidence], app: StoreApp, keywordsChosen: Bool, hasApprovedVersion: Bool,
        analytics: AnalyticsStore, reviews: ReviewsStore
    ) -> [String] {
        var problems: [String] = []
        for item in evidence {
            if item.ref.count > detailLimit {
                problems.append(String(localized: """
                An evidence detail holds \(detailLimit) characters (“\(item.ref.prefix(24))…” has \(item.ref.count)): it's the \
                pill's label, e.g. “Brazil: 4% open the page”. Put the rest in reason.
                """))
            }
            switch item.kind {
            case "analytics":
                if analytics.setup(for: app.id) != .ready {
                    problems.append(String(localized: """
                    Atlas has no Analytics numbers for \(app.name) on this Mac, so the person can't see analytics evidence. \
                    Base it on the reviews or the approved keywords, or leave analytics out.
                    """))
                }
            case "reviews":
                if reviews.archive(for: app.id).reviews.isEmpty {
                    problems.append(String(localized: """
                    Atlas has no reviews of \(app.name) on this Mac yet: read them with get_reviews first, so the person can \
                    see the ones you mean.
                    """))
                }
            case "keywords":
                if !hasApprovedVersion {
                    problems.append(String(localized: "No version of \(app.name) is approved yet, so there are no approved keywords to base it on."))
                } else if !keywordsChosen {
                    problems.append(String(localized: "keywords evidence needs the page to choose some of the approved version's keywords."))
                }
            default:
                problems.append(String(localized: """
                “\(item.kind)” isn't evidence Atlas can show the person: use analytics (get_analytics_funnel, or \
                get_analytics_breakdown by source, language, territory or productPage), reviews (get_reviews) or keywords \
                (the approved version's).
                """))
            }
        }
        return problems
    }

    /// `[{source, detail}]` in results.
    static func json(_ evidence: [SuggestionEvidence]) -> JSONValue {
        .array(evidence.map { item in
            item.ref.isEmpty ? ["source": .string(item.kind)] : ["source": .string(item.kind), "detail": .string(item.ref)]
        })
    }
}
