//
//  InAppEventChangeBuilder+NewLanguageArtwork.swift
//  Atlas
//

import Foundation

// An event's card and details page go into every language, the ones its
// queued texts create too: a language queued after the art gets a copy of
// the art queued for the event's own language, and a new language taken
// out of the queue takes its images with it.
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

    /// What to queue and take out so `event`'s new languages have the
    /// art the event has queued, and no images wait for a language that
    /// isn't coming.
    func newLanguageArtwork(of event: InAppEvent, in changes: [PendingChange]) -> (add: [PendingChange], discard: [PendingChange.ID]) {
        let queued = queuedArtwork(for: event.id, in: changes)
        let existing = Set(event.localizations.map(\.locale))
        let coming = Set(newLanguages(of: event.id, in: changes)).subtracting(existing)
        let primary = event.primaryLocale ?? event.localizations.first?.locale
        var add: [PendingChange] = []
        for kind in InAppEventMedia.Kind.allCases {
            let ofKind = queued.filter { $0.kind == kind }
            let template = ofKind.first { $0.locale == primary } ?? ofKind.first { existing.contains($0.locale) } ?? ofKind.first
            guard let template, let change = changes.first(where: { $0.id == template.changeID }) else { continue }
            let covered = Set(ofKind.map(\.locale))
            for locale in coming.sorted() where !covered.contains(locale) {
                add.append(copy(change, of: template, to: locale, of: event))
            }
        }
        let discard = queued.filter { art in
            EventLocalizationPlaceholder.isPlaceholder(art.push.localizationID) && !coming.contains(art.locale) && !existing.contains(art.locale)
        }
        return (add, discard.map(\.changeID))
    }

    /// `change`, the art queued for one language, into the new `locale`.
    private func copy(_ change: PendingChange, of art: InAppEventQueuedArtwork, to locale: String, of event: InAppEvent) -> PendingChange {
        var push = art.push
        push.localizationID = EventLocalizationPlaceholder(eventID: event.id, locale: locale).token
        var copy = change
        copy.id = artworkChangeID(eventID: event.id, kind: art.kind, locale: locale)
        copy.title = "\(Self.localeName(locale)) · \(art.kind.title)"
        copy.flagRegion = Self.region(locale)
        copy.oldValue = Self.mediaValue(nil)
        copy.requests = [push.request]
        copy.restoreRequests = []
        copy.conflictCheck = nil
        copy.remoteConflict = nil
        copy.alternative = nil
        return copy
    }
}
