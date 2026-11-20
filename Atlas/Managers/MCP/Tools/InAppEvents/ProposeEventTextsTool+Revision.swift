//
//  ProposeEventTextsTool+Revision.swift
//  Atlas
//

import Foundation

// `propose_event_texts` with `revise`: some texts of a language the event
// already has, changed ("…by Sunday" when it now ends on a Wednesday),
// with why. Only the texts sent and different from the current ones
// (queued, else App Store Connect's) are revised; the others stay. The
// same limits and guidance as new texts, refused with the reason. The
// result shows each change against the current text.
extension ProposeEventTextsTool {
    /// The revision `value` asks for: the suggestion and its changes, or
    /// no suggestion and why it was skipped. `queued` is the language's
    /// texts waiting in Review & Push.
    static func revision(
        _ value: JSONValue, locale: String, of event: InAppEvent, queued: [InAppEventField: String], source: String, date: Date = .now
    ) -> (suggestion: InAppEventTextSuggestion?, json: JSONValue) {
        func skip(_ reason: String, issues: [StoreTextGuidelineIssue] = []) -> (suggestion: InAppEventTextSuggestion?, json: JSONValue) {
            var json: [String: JSONValue] = ["locale": .string(locale), "reason": .string(reason), "revise": true]
            if !issues.isEmpty { json["issues"] = .array(issues.map(\.json)) }
            return (nil, .object(json))
        }
        guard StoreLocaleCatalog.locale(code: locale) != nil else { return skip("“\(locale)” isn’t an App Store locale code.") }
        guard let localization = event.localization(locale) else {
            return skip("“\(locale)” isn’t written yet, so there’s nothing to revise: send all three texts without revise.")
        }
        let why = trimmed(value["why"])
        guard !why.isEmpty else { return skip("A revision needs why: one sentence for the person on why these texts change.") }
        let current = { (field: InAppEventField) in queued[field] ?? localization.text(field) }
        let changed = changedTexts(in: value, current: current)
        guard let texts = changed.texts else { return skip(changed.problem ?? "") }
        let suggestion = InAppEventTextSuggestion(
            eventID: event.id, locale: locale, name: texts[.name] ?? "", shortDescription: texts[.shortDescription] ?? "",
            longDescription: texts[.longDescription] ?? "", why: String(why.prefix(whyLimit)), source: source, date: date,
            revisedFields: InAppEventField.allCases.filter { texts[$0] != nil }
        )
        if let over = suggestion.overLimit {
            return skip("\(over.field.rawValue) has \(over.count) characters; it holds \(over.field.limit).")
        }
        let issues = guidelineIssues(suggestion)
        guard issues.isEmpty else { return skip(issues.assistantReason + " Fix it and send that language again.", issues: issues) }
        return (suggestion, [
            "locale": .string(locale),
            "changes": .array(suggestion.fields.map { field in changeJSON(field, from: current(field), to: suggestion.text(field)) }),
        ])
    }

    /// The texts `value` sends that differ from the `current` ones, or why
    /// there's nothing to revise: none sent, one empty, or all the same.
    private static func changedTexts(
        in value: JSONValue, current: (InAppEventField) -> String
    ) -> (texts: [InAppEventField: String]?, problem: String?) {
        var sent = false
        var texts: [InAppEventField: String] = [:]
        for field in InAppEventField.allCases {
            guard let text = value[field.rawValue]?.stringValue else { continue }
            let written = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !written.isEmpty else { return (nil, "\(field.rawValue) is empty: leave a text out to keep it as it is.") }
            sent = true
            if written != current(field) { texts[field] = written }
        }
        guard sent else { return (nil, "Send the texts to change: name, shortDescription or longDescription.") }
        guard !texts.isEmpty else { return (nil, "These are its texts already (queued or in App Store Connect): nothing to revise.") }
        return (texts, nil)
    }

    /// One revised text against the current one: `{field, now, suggested,
    /// marked, removed, added}`.
    static func changeJSON(_ field: InAppEventField, from now: String, to suggested: String) -> JSONValue {
        let diff = TextWordDiff(from: now, to: suggested)
        return [
            "field": .string(field.rawValue),
            "now": .string(now),
            "suggested": .string(suggested),
            "marked": .string(diff.marked),
            "removed": .array(diff.removedWords.map(JSONValue.string)),
            "added": .array(diff.addedWords.map(JSONValue.string)),
        ]
    }
}
