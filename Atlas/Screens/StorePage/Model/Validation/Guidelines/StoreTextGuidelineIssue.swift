//
//  StoreTextGuidelineIssue.swift
//  Atlas
//

import Foundation

/// One rule a text breaks, with the words that break it as written:
/// pricing, “free” and “7 days”.
nonisolated struct StoreTextGuidelineIssue: Hashable, Sendable {
    var kind: StoreTextGuidelineKind
    /// In the order they appear, each once whatever its case.
    var phrases: [String]
    /// Where the text goes when it isn't the store listing, an in-app
    /// text or a caption: its rule and guideline are that place's.
    var place: StoreTextGuidelinePlace?

    /// “free”, “$4.99” and 2 more.
    var quotedPhrases: String {
        let shown = phrases.prefix(3).map { "“\($0)”" }
        let rest = phrases.count - shown.count
        return rest > 0
            ? String(localized: "\(shown.joined(separator: ", ")) and \(rest) more")
            : shown.formatted(.list(type: .and))
    }

    /// "App Review rejects pricing in store text and screenshots (Guideline
    /// 2.3.7): “free”." As the Store Page shows it under the field.
    var message: String {
        let rule = place?.rule(for: kind) ?? kind.rule
        let label = place?.guidelineLabel(for: kind) ?? kind.guidelineLabel
        return String(localized: "\(rule) (\(label)): \(quotedPhrases).")
    }

    /// The message and how to fix it, for an assistant.
    var assistantReason: String {
        "\(message) \(place?.advice(for: kind) ?? kind.advice)"
    }

    /// `{kind, guideline, phrases}` in tool results.
    var json: JSONValue {
        [
            "kind": .string(kind.rawValue),
            "guideline": .string(place?.guideline(for: kind) ?? kind.guideline),
            "phrases": .array(phrases.map(JSONValue.string)),
        ]
    }
}

extension [StoreTextGuidelineIssue] {
    /// Every issue's reason, one after the other.
    nonisolated var assistantReason: String {
        map(\.assistantReason).joined(separator: " ")
    }

    /// What get_listing and get_store_page put in a field's state: "App
    /// Review would reject it: … Propose a version without it."
    nonisolated var assistantNote: String {
        String(localized: "App Review would reject it: \(map(\.message).joined(separator: " ")) Propose a version without it.")
    }
}
