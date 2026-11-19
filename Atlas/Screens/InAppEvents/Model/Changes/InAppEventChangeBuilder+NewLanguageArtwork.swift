//
//  InAppEventChangeBuilder+NewLanguageArtwork.swift
//  Atlas
//

import Foundation

// Art for a language the push creates: queued only when someone names that
// language (Apple shows the primary language's art in a language without
// its own, so Atlas no longer copies it there by itself), and taken out
// with the language's texts.
extension InAppEventChangeBuilder {
    /// The languages `eventID` gets from queued texts (`….<locale>.new`).
    func newLanguages(of eventID: String, in changes: [PendingChange]) -> [String] {
        let prefix = "\(idPrefix)\(eventID)."
        let suffix = ".\(Self.newSuffix)"
        return changes.compactMap { change in
            guard owns(change), change.id.hasPrefix(prefix), change.id.hasSuffix(suffix) else { return nil }
            return String(change.id.dropFirst(prefix.count).dropLast(suffix.count))
        }
        .sorted()
    }

    /// The art waiting for a language of `event` that isn't coming any
    /// more: the event doesn't have it and no queued texts create it.
    func orphanedNewLanguageArtwork(of event: InAppEvent, in changes: [PendingChange]) -> [PendingChange.ID] {
        let existing = Set(event.localizations.map(\.locale))
        let coming = Set(newLanguages(of: event.id, in: changes))
        return queuedArtwork(for: event.id, in: changes)
            .filter { art in
                EventLocalizationPlaceholder.isPlaceholder(art.push.localizationID) && !coming.contains(art.locale) && !existing.contains(art.locale)
            }
            .map(\.changeID)
    }
}
