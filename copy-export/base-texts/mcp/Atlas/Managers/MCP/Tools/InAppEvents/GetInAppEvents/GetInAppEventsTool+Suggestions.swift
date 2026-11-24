//
//  GetInAppEventsTool+Suggestions.swift
//  Atlas
//

import Foundation

// The text suggestions waiting for the person in In-App Events, as
// `get_in_app_events` shows them: each with its texts and who sent it (a
// revision with only the texts it changes, `revision` and `revises`), and
// `stale` once App Store Connect has that language written (someone wrote
// it there, or a push did; for a revision, once it has those texts), so
// the one who sent it can withdraw it. The tool settles the store first
// (`InAppEventsStore.noteRead`): done ones are gone and a new language
// written since is a revision, so `stale` is only for what that leaves.
extension GetInAppEventsTool {
    /// `openSuggestions` and `staleSuggestions`; nothing when none wait.
    static func suggestionsJSON(_ suggestions: [InAppEventTextSuggestion], of event: InAppEvent) -> [String: JSONValue] {
        guard !suggestions.isEmpty else { return [:] }
        let sorted = suggestions.sorted { $0.locale < $1.locale }
        return [
            "openSuggestions": .array(sorted.map { suggestion in
                var json: [String: JSONValue] = [
                    "locale": .string(suggestion.locale),
                    "by": .string(suggestion.source),
                    "suggestedAt": .string(suggestion.date.formatted(.iso8601)),
                    "stale": .bool(suggestion.isStale(in: event)),
                    "why": .string(suggestion.why),
                ]
                for field in suggestion.fields {
                    json[field.rawValue] = .string(suggestion.text(field))
                }
                if suggestion.isRevision {
                    json["revision"] = true
                    json["revises"] = .array(suggestion.fields.map { .string($0.rawValue) })
                }
                return .object(json)
            }),
            "staleSuggestions": .array(sorted.filter { $0.isStale(in: event) }.map { .string($0.locale) }),
        ]
    }
}
