//
//  InAppEventsViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// In-App Events for one app: the gallery of events or one event's page,
/// the event's texts in the selected language (App Store Connect's with
/// what's queued on top), the languages an assistant suggested, and
/// accepting them.
@MainActor
@Observable
final class InAppEventsViewModel {
    let app: StoreApp
    let services: any InAppEventsServices
    let store: InAppEventsStore
    let queue: ChangeQueue

    private(set) var state: LoadState<[InAppEvent]> = .idle
    var selectedEventID: InAppEvent.ID?
    /// The selected event's page rather than the gallery.
    var showsEvent = false
    /// The preview's Event Card or Event Details.
    var previewKind: InAppEventMedia.Kind = .card
    /// The name button's menu of the other events.
    var isSwitchMenuShown = false
    /// The language the editor shows.
    var localeCode = "en-US"
    /// The store page's languages, to localize events into.
    var pageLocales: [String] = []
    /// The app's version on its way ("1.4") and the events going to App
    /// Review with it; the section sets them from the release status.
    var versionString: String?
    var versionEventIDs: Set<InAppEvent.ID> = []
    /// How an ended event did, when Apple's numbers are on this Mac.
    var results: [InAppEvent.ID: InAppEventResults] = [:]
    var toast: ToastMessage?
    var undo: InAppEventsUndo?
    var isNewEventPresented = false
    var actionError: String?
    var isSubmitting = false
    /// Each event's artwork runs; the section sets it.
    var artworkStudio: EventArtworkStudio?
    /// The event page's artwork: the Brief sheet, the concepts, the viewer.
    var artworkFlow: EventArtworkFlow?
    /// Make the Artwork… or Choose Files…, for the section to handle.
    var artworkRequest: EventArtworkRequest?
    @ObservationIgnored var now: () -> Date = { .now }

    init(app: StoreApp, services: any InAppEventsServices, store: InAppEventsStore, queue: ChangeQueue) {
        self.app = app
        self.services = services
        self.store = store
        self.queue = queue
        localeCode = app.primaryLocale ?? "en-US"
    }

    var builder: InAppEventChangeBuilder { InAppEventChangeBuilder(appID: app.id) }

    // MARK: - Loading

    func load(force: Bool = false) async {
        guard force || state.value == nil, !state.isLoading else { return }
        if state.value == nil { state = .loading }
        do {
            let events = try await services.events(for: app)
            state = .loaded(events)
            store.prune(for: app.id, keeping: Set(events.filter(\.state.isEditable).map(\.id)))
            for event in events where event.state.isEditable { matchNewLanguageArtwork(of: event) }
            if selectedEvent == nil { select(events.first?.id) }
        } catch {
            if state.value == nil { state = .failed(error.localizedDescription) }
        }
    }

    var events: [InAppEvent] { state.value ?? [] }

    var selectedEvent: InAppEvent? {
        events.first { $0.id == selectedEventID }
    }

    /// Selects an event, on the language being viewed when it has it, else
    /// on its primary one.
    func select(_ id: InAppEvent.ID?) {
        selectedEventID = id
        guard let event = selectedEvent else { return }
        let codes = languages(of: event).map(\.code)
        if !codes.contains(localeCode) { localeCode = event.primaryLocale ?? codes.first ?? localeCode }
    }

    func status(of event: InAppEvent) -> InAppEventStatus {
        InAppEventStatus(event, goingWithVersion: versionEventIDs.contains(event.id) ? versionString : nil)
    }

    // MARK: - Languages

    /// The event's languages: its own, the store page's and the suggested
    /// ones, the primary first, then by name.
    func languages(of event: InAppEvent) -> [InAppEventLanguage] {
        let drafts = builder.drafts(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents))
        let suggested = Set(store.open(for: app.id, eventID: event.id).map(\.locale))
        var codes = Set(event.localizations.map(\.locale)).union(drafts.keys).union(suggested)
        if event.state.isEditable { codes.formUnion(pageLocales) }
        let primary = event.primaryLocale
        return codes.sorted { lhs, rhs in
            if (lhs == primary) != (rhs == primary) { return lhs == primary }
            return InAppEventChangeBuilder.localeName(lhs) < InAppEventChangeBuilder.localeName(rhs)
        }
        .map { code in
            let state: InAppEventLanguage.State = if drafts[code]?.isEmpty == false {
                .notPushed
            } else if event.localization(code)?.isComplete == true {
                .written
            } else if suggested.contains(code), event.state.isEditable {
                .suggested
            } else {
                event.localization(code) == nil ? .missing : .written
            }
            return InAppEventLanguage(code: code, state: state)
        }
    }

    var selectedLanguage: InAppEventLanguage? {
        selectedEvent.flatMap { languages(of: $0).first { $0.code == localeCode } }
    }

    /// Languages of the selected event with a suggestion waiting.
    var suggestedCount: Int {
        selectedEvent.map { languages(of: $0).count { $0.state == .suggested } } ?? 0
    }

    /// "9 languages suggested by Claude Code".
    var suggestionsTitle: String {
        guard let event = selectedEvent else { return "" }
        let count = suggestedCount
        guard count > 0 else {
            let missing = languages(of: event).count { $0.state == .missing }
            return missing == 0 ? String(localized: "Every language written or accepted") : String(localized: "\(ReviewText.languages(missing)) not written yet")
        }
        let source = store.open(for: app.id, eventID: event.id).first?.source ?? ""
        return source.isEmpty
            ? String(localized: "\(ReviewText.languages(count)) suggested")
            : String(localized: "\(ReviewText.languages(count)) suggested by \(source)")
    }

    // MARK: - Texts

    /// The suggestion showing for the selected event and language: only
    /// while nothing is written there.
    var suggestion: InAppEventTextSuggestion? {
        guard let event = selectedEvent, selectedLanguage?.state == .suggested else { return nil }
        return store.suggestion(for: app.id, eventID: event.id, locale: localeCode)
    }

    /// The text in the selected language: what's queued, else what App
    /// Store Connect has.
    func text(_ field: InAppEventField) -> String {
        guard let event = selectedEvent else { return "" }
        return text(field, of: event, locale: localeCode)
    }

    func text(_ field: InAppEventField, of event: InAppEvent, locale: String) -> String {
        let drafts = builder.drafts(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents))
        return drafts[locale]?[field] ?? event.localization(locale)?.text(field) ?? ""
    }

    /// What people in a language without its own text see: the primary
    /// language's.
    func fallbackText(_ field: InAppEventField) -> String {
        guard let event = selectedEvent, let primary = event.primaryLocale ?? event.localizations.first?.locale else { return "" }
        return text(field, of: event, locale: primary)
    }

    func isPending(_ field: InAppEventField) -> Bool {
        guard let event = selectedEvent else { return false }
        return text(field) != (event.localization(localeCode)?.text(field) ?? "")
    }

    var canEdit: Bool { selectedEvent?.state.isEditable ?? false }

    /// The person typed in a field: queued like any other change.
    func edit(_ field: InAppEventField, to value: String) {
        guard let event = selectedEvent, canEdit, text(field) != value else { return }
        write([field: value], locale: localeCode, of: event, source: .you)
    }

    /// Queues `texts` for one language of `event`: a `PATCH` per text of a
    /// language it has, or one `POST` with every text of a new one.
    func write(_ texts: [InAppEventField: String], locale: String, of event: InAppEvent, source: ChangeSource) {
        let builder = builder
        if let localization = event.localization(locale) {
            for (field, value) in texts {
                let id = builder.changeID(eventID: event.id, locale: locale, field: field)
                if let change = builder.fieldChange(field, to: value, in: localization, of: event, source: source) {
                    queue.upsert(change)
                } else {
                    queue.discard(id: id)
                }
            }
        } else {
            let id = builder.newChangeID(eventID: event.id, locale: locale)
            var all = builder.drafts(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents))[locale] ?? [:]
            all.merge(texts) { _, new in new }
            if let change = builder.newLanguageChange(all, locale: locale, of: event, source: source) {
                queue.upsert(change)
            } else {
                queue.discard(id: id)
            }
            matchNewLanguageArtwork(of: event)
        }
    }

    /// The event's new languages get the art queued for it, and images
    /// for a language no longer coming leave the queue.
    func matchNewLanguageArtwork(of event: InAppEvent) {
        let (add, discard) = builder.newLanguageArtwork(of: event, in: queue.changes(for: app.id, section: .inAppEvents))
        queue.upsert(contentsOf: add)
        queue.discard(ids: discard)
    }

    #if DEBUG
    /// DEBUG scenes and tests: the events as if just read.
    func load(events: [InAppEvent]) {
        state = .loaded(events)
        if selectedEvent == nil { select(events.first?.id) }
    }
    #endif
}
