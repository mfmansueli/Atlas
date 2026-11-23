//
//  AssistantTextLimits.swift
//  Atlas
//

import Foundation

/// The house limits for what an assistant writes on a card (README-DS §9,
/// "Text written by the assistant"): a title of at most 8 words, a why of one
/// sentence, details on demand, a gloss and how sure it is. The App Store's
/// own field limits are separate (Apple's rules, checked by each field).
/// Each check gives the reason a text is refused, so the assistant rewrites it.
enum AssistantTextLimits {
    static let titleWords = 8
    static let titleCharacters = 60
    /// A `why` or `reason`: the card's why line.
    static let why = 110
    static let details = 400
    static let gloss = 110
    static let confidence = 1...3

    /// `field` names it as the assistant sent it, e.g. `why` or
    /// `items[2].reason`. `hasDetails`: whether the call takes `details`
    /// beside it, where the rest can go.
    static func whyRefusal(_ text: String, field: String, hasDetails: Bool = true) -> String? {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard count > why else { return nil }
        return hasDetails
            ? String(localized: "\(field) is \(count) characters; at most \(why). Move the rest to details.", comment: "kind:error")
            : String(localized: "\(field) is \(count) characters; at most \(why). Keep one sentence.", comment: "kind:error")
    }

    static func detailsRefusal(_ text: String, field: String) -> String? {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard count > details else { return nil }
        return String(localized: "\(field) is \(count) characters; at most \(details). Keep the numbers that decide it.", comment: "kind:error")
    }

    static func glossRefusal(_ text: String, field: String) -> String? {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard count > gloss else { return nil }
        return String(localized: "\(field) is \(count) characters; at most \(gloss). Say what it means, not word for word.", comment: "kind:error")
    }

    /// A title: what changes, result first.
    static func titleRefusal(_ text: String, field: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "\(field) is empty: say what changes or what you saw.", comment: "kind:error") }
        let words = wordCount(trimmed)
        if words > titleWords {
            return String(localized: "\(field) has \(words) words; at most \(titleWords). Move the rest to why or details.", comment: "kind:error")
        }
        if trimmed.count > titleCharacters {
            return String(
                localized: "\(field) is \(trimmed.count) characters; at most \(titleCharacters). Move the rest to why or details.",
                comment: "kind:error"
            )
        }
        return nil
    }

    /// `confidence` as sent: a whole number from 1 to 3.
    static func confidenceRefusal(_ value: JSONValue, field: String) -> String? {
        if value.isNull { return nil }
        if let number = value.intValue, confidence.contains(number) { return nil }
        let sent = value.intValue.map(String.init) ?? value.jsonString()
        return String(localized: "\(field) is \(sent); send 1 (not very sure), 2 (fairly sure) or 3 (sure).", comment: "kind:error")
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
