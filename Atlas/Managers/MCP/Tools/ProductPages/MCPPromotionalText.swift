//
//  MCPPromotionalText.swift
//  Atlas
//

import Foundation

/// One language's promotional text from an assistant, checked the way the
/// product page tools keep it: offered to accept, kept as Not offered (App
/// Review would reject it: a price, "free", a discount, another
/// platform…), or not kept at all (a language the app doesn't have, over
/// 170 characters), with how to fix it.
@MainActor
enum MCPPromotionalText {
    enum Check {
        case offered(locale: String, text: String)
        case notOffered(locale: String, text: String, issues: [StoreTextGuidelineIssue])
        case empty(locale: String)
        case problem(String)

        /// The App Store code it was checked under; nil for a problem.
        var locale: String? {
            switch self {
            case let .offered(locale, _), let .notOffered(locale, _, _), let .empty(locale): locale
            case .problem: nil
            }
        }
    }

    static func check(locale code: String, text: String, in state: MCPProductPages) -> Check {
        guard let locale = state.locale(code) else { return .problem(localeProblem(code, in: state)) }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty(locale: locale) }
        if text.count > ProductPageField.promotionalTextLimit {
            return .problem(String(localized: """
            \(locale): the promotional text has \(text.count) characters; it holds \(ProductPageField.promotionalTextLimit). \
            Shorten it and send it again.
            """))
        }
        let issues = StoreTextGuidelineCheck.issues(in: text, for: ListingField.promotionalText)
        return issues.isEmpty ? .offered(locale: locale, text: text) : .notOffered(locale: locale, text: text, issues: issues)
    }

    /// "“xx” isn't one of Lumen Journal's languages: en-US, de-DE…".
    static func localeProblem(_ code: String, in state: MCPProductPages) -> String {
        guard StoreLocaleCatalog.locale(code: code) != nil else {
            return String(localized: "“\(code)” isn't an App Store locale code, e.g. en-US or de-DE.")
        }
        return String(localized: """
        “\(code)” isn't one of \(state.app.name)'s App Store languages (\(state.defaultPage.locales.joined(separator: ", "))): a \
        page has only those.
        """)
    }

    /// The suggestion Atlas keeps for a text it stopped: shown as Not
    /// offered, with the phrases marked and why.
    static func refused(
        pageID: String, locale: String, text: String, issues: [StoreTextGuidelineIssue], reason: String, source: String,
        evidence: [SuggestionEvidence]? = nil, layers: SuggestionLayers? = nil
    ) -> ProductPageTextSuggestion {
        ProductPageTextSuggestion(
            pageID: pageID, locale: locale, text: text, reason: reason, source: source,
            refusal: ProductPageTextRefusal.reason(for: issues), refusedPhrases: issues.flatMap(\.phrases), evidence: evidence,
            layers: layers
        )
    }

    /// `notOffered` in results: the language, why, and the rules' phrases.
    static func notOfferedJSON(locale: String, issues: [StoreTextGuidelineIssue]) -> JSONValue {
        [
            "locale": .string(locale),
            "reason": .string(ProductPageTextRefusal.assistantReason(for: issues) + " " + String(localized: """
            The person sees it as Not offered and can't accept it: write another for this language.
            """)),
            "issues": .array(issues.map(\.json)),
        ]
    }
}
