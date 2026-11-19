//
//  GetInAppEventsTool+Suggestions.swift
//  Atlas
//

import Foundation

// The text suggestions waiting for the person in In-App Events, as
// `get_in_app_events` shows them: each with its texts and who sent it, and
// `stale` once App Store Connect has that language written (someone wrote
// it there, or a push did), so the one who sent it can withdraw it.
extension GetInAppEventsTool {
    /// `openSuggestions` and `staleSuggestions`; nothing when none wait.
    static func suggestionsJSON(_ suggestions: [InAppEventTextSuggestion], of event: InAppEvent) -> [String: JSONValue] {
        guard !suggestions.isEmpty else { return [:] }
        let sorted = suggestions.sorted { $0.locale < $1.locale }
        return [
            "openSuggestions": .array(sorted.map { suggestion in
                [
                    "locale": .string(suggestion.locale),
                    "by": .string(suggestion.source),
                    "suggestedAt": .string(suggestion.date.formatted(.iso8601)),
                    "stale": .bool(suggestion.isStale(in: event)),
                    "name": .string(suggestion.name),
                    "shortDescription": .string(suggestion.shortDescription),
                    "longDescription": .string(suggestion.longDescription),
                    "why": .string(suggestion.why),
                ]
            }),
            "staleSuggestions": .array(sorted.filter { $0.isStale(in: event) }.map { .string($0.locale) }),
        ]
    }
}
