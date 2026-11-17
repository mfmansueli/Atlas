//
//  InAppEventsViewModel+Suggestions.swift
//  Atlas
//

import Foundation

// Accepting and dismissing the languages an assistant suggested. Accepted
// texts wait in Review & Push; the toast's Undo puts the suggestions back.
extension InAppEventsViewModel {
    /// Accept on the suggestion showing.
    func acceptSuggestion() {
        guard let event = selectedEvent, let suggestion else { return }
        accept([suggestion], of: event)
        let name = InAppEventChangeBuilder.localeName(suggestion.locale)
        toast = ToastMessage(text: String(localized: "Accepted \(name). It’s in Review & Push."), canUndo: true, actionTitle: String(localized: "Review & Push"))
    }

    /// Dismiss on the suggestion showing: people there keep seeing the
    /// primary language.
    func dismissSuggestion() {
        guard let suggestion else { return }
        store.dismiss(suggestion.id, for: app.id)
    }

    /// Accept All Languages: every language of the event with a suggestion.
    func acceptAllLanguages() {
        guard let event = selectedEvent else { return }
        let waiting = Set(languages(of: event).filter { $0.state == .suggested }.map(\.code))
        let batch = store.open(for: app.id, eventID: event.id).filter { waiting.contains($0.locale) }
        guard !batch.isEmpty else { return }
        accept(batch, of: event)
        let name = ReleaseViewModel.displayName(of: event)
        toast = ToastMessage(
            text: String(localized: "Accepted \(ReviewText.languages(batch.count)) for \(name). They’re in Review & Push."),
            canUndo: true, actionTitle: String(localized: "Review & Push")
        )
    }

    private func accept(_ batch: [InAppEventTextSuggestion], of event: InAppEvent) {
        let builder = builder
        var previous: [PendingChange.ID: PendingChange?] = [:]
        for suggestion in batch {
            for id in builder.changeIDs(eventID: event.id, locale: suggestion.locale) {
                previous[id] = .some(queue.change(id: id))
            }
            let texts = Dictionary(uniqueKeysWithValues: InAppEventField.allCases.map { ($0, suggestion.text($0)) })
            write(texts, locale: suggestion.locale, of: event, source: .assistant(client: suggestion.source))
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
    }

    /// "Not localized yet: people in German see the event in English."
    var fallbackNote: String? {
        guard let event = selectedEvent, let language = selectedLanguage, language.state == .suggested || language.state == .missing,
              language.code != event.primaryLocale else { return nil }
        let primary = event.primaryLocale.map(InAppEventChangeBuilder.localeName) ?? String(localized: "the primary language")
        return String(localized: "Not localized yet: people who read \(language.name) see the event in \(primary).")
    }
}
