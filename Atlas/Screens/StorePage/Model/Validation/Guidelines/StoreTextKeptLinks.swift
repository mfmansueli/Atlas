//
//  StoreTextKeptLinks.swift
//  Atlas
//

import Foundation

/// The Terms of Use (EULA) and Privacy Policy links a description carries,
/// so an assistant's rewrite that drops one is refused: an app with
/// auto-renewable subscriptions needs both in its metadata, and the
/// description is where the Terms of Use link usually is (Guideline
/// 3.1.2(c)). A link counts by its address ("/terms", "stdeula",
/// "/privacy") or by the words before it on its line ("Terms of Use:").
nonisolated enum StoreTextKeptLinks {
    enum Kind: String, CaseIterable, Hashable, Sendable {
        case termsOfUse
        case privacyPolicy

        /// "Terms of Use (EULA)".
        var name: String {
            switch self {
            case .termsOfUse: String(localized: "Terms of Use (EULA)", comment: "kind:label · a link in the description")
            case .privacyPolicy: String(localized: "Privacy Policy", comment: "kind:label · a link in the description")
            }
        }
    }

    struct Link: Hashable, Sendable {
        var kind: Kind
        var url: String
    }

    /// The Terms of Use and Privacy Policy links in `text`, in order.
    static func links(in text: String) -> [Link] {
        let range = NSRange(text.startIndex..., in: text)
        return (url?.matches(in: text, range: range) ?? []).compactMap { match in
            guard let found = Range(match.range, in: text) else { return nil }
            let address = String(text[found]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            guard let kind = kind(ofURL: address) ?? kind(ofWords: context(before: found, in: text)) else { return nil }
            return Link(kind: kind, url: address)
        }
    }

    /// The links `current` has whose kind `proposed` has none of (by
    /// address or by words): the first of each kind dropped.
    static func dropped(from current: String, in proposed: String) -> [Link] {
        let kept = links(in: proposed)
        let keptURLs = Set(kept.map { normalized($0.url) })
        let proposedText = proposed.lowercased()
        var dropped: [Link] = []
        for link in links(in: current) where !dropped.contains(where: { $0.kind == link.kind }) {
            let stays = kept.contains { $0.kind == link.kind } || keptURLs.contains(normalized(link.url))
                || proposedText.contains(normalized(link.url))
            if !stays { dropped.append(link) }
        }
        return dropped
    }

    /// Why the rewrite is refused and how to fix it, for the assistant.
    static func refusal(_ dropped: [Link]) -> String? {
        guard !dropped.isEmpty else { return nil }
        let names = dropped.map(\.kind.name).formatted(.list(type: .and))
        let urls = dropped.map(\.url).formatted(.list(type: .and))
        return String(localized: """
        The description has a \(names) link (\(urls)) and this text drops it. An app with auto-renewable subscriptions needs \
        it in the metadata, or App Review rejects the version (Guideline 3.1.2(c)). Keep the link in the text and send it again.
        """, comment: "kind:error · an assistant's description rewrite is refused")
    }

    // MARK: - Reading

    private static let url = try? NSRegularExpression(pattern: "(?:https?://|www\\.)[^\\s<>()\\[\\]\"“”'‘’]+", options: [.caseInsensitive])

    /// Lower case, without the scheme, "www." and a trailing "/".
    private static func normalized(_ url: String) -> String {
        var text = url.lowercased()
        for prefix in ["https://", "http://", "www."] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }

    /// By the address's words: "/terms-of-use", "stdeula", "/datenschutz".
    private static func kind(ofURL url: String) -> Kind? {
        let parts = url.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        if parts.contains(where: { part in termsParts.contains(part) || part.hasPrefix("termsof") || part.hasPrefix("eula") }) {
            return .termsOfUse
        }
        if parts.contains(where: { part in privacyParts.contains(part) || part.hasPrefix("privacy") || part.hasPrefix("datenschutz") }) {
            return .privacyPolicy
        }
        return nil
    }

    private static let termsParts: Set<String> = [
        "terms", "tos", "eula", "stdeula", "conditions", "agb", "nutzungsbedingungen", "termos", "terminos", "condiciones",
        "condizioni", "voorwaarden", "villkor", "cgu", "cgv",
    ]

    private static let privacyParts: Set<String> = [
        "privacy", "privacypolicy", "datenschutz", "datenschutzerklarung", "privacidade", "privacidad", "confidentialite",
        "privacybeleid", "integritetspolicy", "riservatezza",
    ]

    /// The words before the link on its line, or the line before when the
    /// link stands alone ("Terms of Use:" then the link).
    private static func context(before found: Range<String.Index>, in text: String) -> String {
        let before = text[..<found.lowerBound]
        let lines = before.split(separator: "\n", omittingEmptySubsequences: false)
        let line = lines.last.map(String.init) ?? ""
        let words = line.trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters).union(.symbols))
        if words.isEmpty, lines.count > 1 {
            return lines.dropLast().last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }).map(String.init) ?? ""
        }
        return String(line.suffix(80))
    }

    /// By the words: the kind named last wins ("Privacy Policy and Terms
    /// of Use: …" is the terms link).
    private static func kind(ofWords words: String) -> Kind? {
        let folded = words.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        let terms = lastMatch(of: termsWords, in: folded)
        let privacy = lastMatch(of: privacyWords, in: folded)
        switch (terms, privacy) {
        case let (terms?, privacy?): return terms > privacy ? .termsOfUse : .privacyPolicy
        case (.some, nil): return .termsOfUse
        case (nil, .some): return .privacyPolicy
        case (nil, nil): return nil
        }
    }

    private static func lastMatch(of words: [String], in folded: String) -> String.Index? {
        words.compactMap { folded.range(of: $0, options: .backwards)?.lowerBound }.max()
    }

    /// Folded.
    private static let termsWords = [
        "terms", "eula", "license agreement", "licence agreement", "nutzungsbedingungen", "agb", "termos", "terminos",
        "conditions d'utilisation", "conditions generales", "condizioni", "voorwaarden", "villkor", "利用規約", "使用条款", "服务条款",
        "使用條款", "이용약관", "условия",
    ]

    private static let privacyWords = [
        "privacy", "datenschutz", "privacidade", "privacidad", "confidentialite", "riservatezza", "privacybeleid", "integritet",
        "プライバシー", "隐私", "隱私", "개인정보", "конфиденциальност",
    ]
}
