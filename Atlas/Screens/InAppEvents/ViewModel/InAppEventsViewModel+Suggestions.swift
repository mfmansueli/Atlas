//
//  InAppEventsViewModel+Suggestions.swift
//  Atlas
//

import Foundation

// Accepting and dismissing the languages an assistant suggested, and its
// revisions of written ones (Use and Edit too). Accepted texts wait in
// Review & Push; the toast's Undo puts the suggestions back.
extension InAppEventsViewModel {
    /// Accept on the suggestion or the revision showing.
    func acceptSuggestion() {
        guard let event = selectedEvent, let shown = suggestion ?? revision else { return }
        accept([shown], of: event)
        let name = InAppEventChangeBuilder.localeName(shown.locale)
        toast = ToastMessage(text: String(localized: "Accepted \(name). It’s waiting in Review & Push, top right."), canUndo: true, actionTitle: String(localized: "Review & Push"))
    }

    /// Dismiss on the suggestion showing: people there keep seeing the
    /// primary language. On a revision: the texts stay as they are.
    func dismissSuggestion() {
        guard let shown = suggestion ?? revision else { return }
        store.dismiss(shown.id, for: app.id)
    }

    /// Use and Edit on a revision: its texts go in like Accept, and the
    /// first one it changes takes focus to edit.
    func useAndEditRevision() {
        guard let event = selectedEvent, let revision else { return }
        accept([revision], of: event)
        focusedTextField = revision.fields.first
    }

    /// Accept All Languages: every language of the event with a suggestion
    /// or a revision.
    func acceptAllLanguages() {
        guard let event = selectedEvent else { return }
        let batch = shownSuggestions(of: event)
        guard !batch.isEmpty else { return }
        accept(batch, of: event)
        let name = ReleaseViewModel.displayName(of: event)
        toast = ToastMessage(
            text: String(localized: "Accepted \(ReviewText.languages(batch.count)) for \(name). They’re waiting in Review & Push, top right."),
            canUndo: true, actionTitle: String(localized: "Review & Push")
        )
    }

    /// Dismiss All beside Accept All Languages: every suggestion and
    /// revision the event shows goes, and the written texts stay as they
    /// are. The toast's Undo brings them back.
    func dismissAllLanguages() {
        guard let event = selectedEvent else { return }
        let batch = shownSuggestions(of: event)
        guard !batch.isEmpty else { return }
        let ids = Set(batch.map(\.id))
        store.dismiss(ids, for: app.id)
        undo = InAppEventsUndo(suggestions: [], previous: [:], dismissedIDs: ids)
        let name = ReleaseViewModel.displayName(of: event)
        toast = ToastMessage(text: String(localized: "Dismissed \(ReviewText.languages(batch.count)) for \(name)."), canUndo: true)
    }

    /// The suggestions and revisions `event`'s languages show.
    private func shownSuggestions(of event: InAppEvent) -> [InAppEventTextSuggestion] {
        let waiting = Set(languages(of: event).filter { $0.state == .suggested || $0.state == .revision }.map(\.code))
        return store.open(for: app.id, eventID: event.id).filter { waiting.contains($0.locale) }
    }

    private func accept(_ batch: [InAppEventTextSuggestion], of event: InAppEvent) {
        let builder = builder
        var previous: [PendingChange.ID: PendingChange?] = [:]
        for suggestion in batch {
            for id in builder.changeIDs(eventID: event.id, locale: suggestion.locale) {
                previous[id] = .some(queue.change(id: id))
            }
            if suggestion.isRevision {
                // Accepted, it replaces the person's own queued text
                // rather than waiting beside it for a pick.
                queue.discard(ids: suggestion.fields.map { builder.changeID(eventID: event.id, locale: suggestion.locale, field: $0) })
            }
            // A revision writes only the texts it changes.
            write(suggestion.texts, locale: suggestion.locale, of: event, source: .assistant(client: suggestion.source))
        }
        undo = InAppEventsUndo(suggestions: store.remove(Set(batch.map(\.id)), for: app.id), previous: previous)
    }

    /// Undo on the toast.
    func undoAccept() {
        guard let undo else { return }
        self.undo = nil
        toast = nil
        for (id, change) in undo.previous {
            if let change {
                queue.upsert(change)
            } else {
                queue.discard(id: id)
            }
        }
        store.add(undo.suggestions, for: app.id)
        store.restore(undo.dismissedIDs, for: app.id)
        if let key = undo.artwork {
            artworkStudio?.update(key) { run in
                run.usedConceptID = undo.previousConceptID
                run.queuedChangeIDs = undo.previousChangeIDs
            }
        }
    }

    /// "Not localized yet: people in German see the event in English."
    var fallbackNote: String? {
        guard let event = selectedEvent, let language = selectedLanguage, language.state == .suggested || language.state == .missing,
              language.code != event.primaryLocale else { return nil }
        let primary = event.primaryLocale.map(InAppEventChangeBuilder.localeName) ?? String(localized: "the primary language")
        return String(localized: "Not localized yet: people who read \(language.name) see the event in \(primary).")
    }
}
