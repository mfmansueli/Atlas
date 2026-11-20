//
//  InAppEventShownSuggestions.swift
//  Atlas
//

import Foundation

/// The suggestions an event's page shows, by language: a new language's
/// texts while App Store Connect doesn't have that language whole and
/// nothing of it waits in Review & Push, and a revision while it would
/// change a text the language has (queued, else App Store Connect's). An
/// event that can't change any more shows none. The page's languages and
/// the section's purple count both come from here, so the count never
/// points at something the page doesn't show.
struct InAppEventShownSuggestions: Hashable, Sendable {
    /// Languages showing a new language's texts.
    var suggested: Set<String> = []
    /// Written languages showing a revision.
    var revised: Set<String> = []

    /// `open` are the suggestions waiting (any event's: only `event`'s
    /// count), `drafts` the texts waiting in Review & Push for `event`, by
    /// language.
    init(event: InAppEvent, open: [InAppEventTextSuggestion], drafts: [String: [InAppEventField: String]]) {
        guard event.state.isEditable else { return }
        let waiting = open.filter { $0.eventID == event.id }
        revised = Set(waiting.filter { Self.changesSomething($0, of: event, drafts: drafts) }.map(\.locale))
        suggested = Set(waiting.filter { suggestion in
            !suggestion.isRevision && !revised.contains(suggestion.locale) && drafts[suggestion.locale]?.isEmpty != false
                && event.localization(suggestion.locale)?.isComplete != true
        }.map(\.locale))
    }

    /// Languages with something to accept or dismiss.
    var count: Int { suggested.count + revised.count }

    /// Whether a revision would change any text its language has now
    /// (queued, else App Store Connect's).
    static func changesSomething(_ suggestion: InAppEventTextSuggestion, of event: InAppEvent, drafts: [String: [InAppEventField: String]]) -> Bool {
        guard suggestion.isRevision, let localization = event.localization(suggestion.locale) else { return false }
        return suggestion.fields.contains { field in
            (drafts[suggestion.locale]?[field] ?? localization.text(field)) != suggestion.text(field)
        }
    }
}
