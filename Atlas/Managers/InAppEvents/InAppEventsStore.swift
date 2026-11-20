//
//  InAppEventsStore.swift
//  Atlas
//

import Foundation
import Observation

/// The event texts assistants suggested, per app, until they're accepted
/// or dismissed. JSON in Application Support when given a directory; in
/// memory otherwise (tests, DEBUG scenes). In-App Events, the sidebar's
/// count and the MCP tools read it.
@MainActor
@Observable
final class InAppEventsStore {
    static let shared = InAppEventsStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/InAppEvents")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private var archives: [StoreApp.ID: InAppEventsArchive] = [:]
    /// Each app's events as Atlas last read them (In-App Events, the
    /// version's Submit sheet, `get_in_app_events`), for the count. Only
    /// in memory: until a read this launch, the count is every open
    /// suggestion.
    private var readEvents: [StoreApp.ID: [InAppEvent]] = [:]
    @ObservationIgnored private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> InAppEventsArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? InAppEventsArchive()
        archives[appID] = archive
        return archive
    }

    /// The suggestions waiting for one event, or for every event.
    func open(for appID: StoreApp.ID, eventID: InAppEvent.ID? = nil) -> [InAppEventTextSuggestion] {
        archive(for: appID).open.filter { eventID == nil || $0.eventID == eventID }
    }

    func suggestion(for appID: StoreApp.ID, eventID: InAppEvent.ID, locale: String) -> InAppEventTextSuggestion? {
        open(for: appID, eventID: eventID).first { $0.locale == locale }
    }

    /// The purple count on the section: the languages with a suggestion or
    /// a revision the section shows (`InAppEventShownSuggestions`), against
    /// the events last read and `changes`, the app's In-App Events changes
    /// waiting in Review & Push. Before any read, every open suggestion.
    func count(for appID: StoreApp.ID, changes: [PendingChange] = []) -> Int {
        let open = archive(for: appID).open
        guard let events = readEvents[appID] else { return open.count }
        let builder = InAppEventChangeBuilder(appID: appID)
        return events.reduce(0) { total, event in
            total + InAppEventShownSuggestions(event: event, open: open, drafts: builder.drafts(for: event.id, in: changes)).count
        }
    }

    /// The check of `eventID`'s deep link, when it's for `deepLink`: one
    /// for another link is stale.
    func deepLinkReport(for appID: StoreApp.ID, eventID: InAppEvent.ID, deepLink: String?) -> InAppEventDeepLinkReport? {
        guard let report = archive(for: appID).deepLinkReports?[eventID], report.isFor(deepLink) else { return nil }
        return report
    }

    // MARK: - Changing

    /// Keeps an assistant's check of an event's deep link, replacing the
    /// one before.
    func setDeepLinkReport(_ report: InAppEventDeepLinkReport, for appID: StoreApp.ID) {
        update(appID) { archive in
            var reports = archive.deepLinkReports ?? [:]
            reports[report.eventID] = report
            archive.deepLinkReports = reports
        }
    }

    /// Drops `eventID`'s check when it's for another deep link than
    /// `deepLink`: the link changed, so it says nothing any more.
    func dropDeepLinkReport(for appID: StoreApp.ID, eventID: InAppEvent.ID, unlessFor deepLink: String?) {
        guard let report = archive(for: appID).deepLinkReports?[eventID], !report.isFor(deepLink) else { return }
        update(appID) { $0.deepLinkReports?[eventID] = nil }
    }

    /// An assistant's suggestions; one for a language that has one replaces
    /// it and comes back if it was dismissed.
    func add(_ suggestions: [InAppEventTextSuggestion], for appID: StoreApp.ID) {
        update(appID) { archive in
            for suggestion in suggestions {
                archive.suggestions.removeAll { $0.id == suggestion.id }
                archive.suggestions.append(suggestion)
                archive.dismissed.remove(suggestion.id)
            }
        }
    }

    func dismiss(_ id: InAppEventTextSuggestion.ID, for appID: StoreApp.ID) {
        dismiss([id], for: appID)
    }

    /// Dismiss All: every one of `ids` at once.
    func dismiss(_ ids: Set<InAppEventTextSuggestion.ID>, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.formUnion(ids) }
    }

    /// Undo of a dismissal: the suggestions wait again.
    func restore(_ ids: Set<InAppEventTextSuggestion.ID>, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.subtract(ids) }
    }

    /// Takes accepted suggestions out; returns them, for Undo.
    @discardableResult
    func remove(_ ids: Set<InAppEventTextSuggestion.ID>, for appID: StoreApp.ID) -> [InAppEventTextSuggestion] {
        var removed: [InAppEventTextSuggestion] = []
        update(appID) { archive in
            removed = archive.suggestions.filter { ids.contains($0.id) }
            archive.suggestions.removeAll { ids.contains($0.id) }
            archive.dismissed.subtract(ids)
        }
        return removed
    }

    /// What a read of the app's events found, so the count never points at
    /// nothing: suggestions for events that are gone or can't be edited any
    /// more go (`prune`), and those App Store Connect caught up with are
    /// settled (`InAppEventTextSuggestion.caughtUp(with:)`): done ones go,
    /// a new language's texts whose language is written now become a
    /// revision of the texts that differ. The count checks what's left
    /// against `events` from then on.
    func noteRead(_ events: [InAppEvent], for appID: StoreApp.ID) {
        if readEvents[appID] != events { readEvents[appID] = events }
        let editable = events.filter(\.state.isEditable)
        prune(for: appID, keeping: Set(editable.map(\.id)))
        let byID = Dictionary(editable.map { ($0.id, $0) }) { first, _ in first }
        update(appID) { archive in
            archive.suggestions = archive.suggestions.compactMap { suggestion in
                guard let event = byID[suggestion.eventID] else { return suggestion }
                return suggestion.caughtUp(with: event)
            }
            archive.dismissed.formIntersection(Set(archive.suggestions.map(\.id)))
        }
    }

    /// Drops suggestions for events that are gone or can't be edited any
    /// more, so the count never points at nothing.
    func prune(for appID: StoreApp.ID, keeping eventIDs: Set<InAppEvent.ID>) {
        update(appID) { archive in
            archive.suggestions.removeAll { !eventIDs.contains($0.eventID) }
            archive.dismissed.formIntersection(Set(archive.suggestions.map(\.id)))
            if let reports = archive.deepLinkReports, reports.keys.contains(where: { !eventIDs.contains($0) }) {
                archive.deepLinkReports = reports.filter { eventIDs.contains($0.key) }
            }
        }
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole state at once.
    func load(_ archive: InAppEventsArchive, for appID: StoreApp.ID) {
        archives[appID] = archive
    }
    #endif

    // MARK: - Files

    private func update(_ appID: StoreApp.ID, _ change: (inout InAppEventsArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: Self.file(appID, in: directory), options: .atomic)
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "events-\(appID).json")
    }

    private static func read(at url: URL) -> InAppEventsArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(InAppEventsArchive.self, from: data)
    }
}
