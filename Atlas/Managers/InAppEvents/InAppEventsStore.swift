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

    /// Languages with a suggestion waiting: the purple count on the section.
    func count(for appID: StoreApp.ID) -> Int {
        archive(for: appID).open.count
    }

    // MARK: - Changing

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
        update(appID) { $0.dismissed.insert(id) }
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

    /// Drops suggestions for events that are gone or can't be edited any
    /// more, so the count never points at nothing.
    func prune(for appID: StoreApp.ID, keeping eventIDs: Set<InAppEvent.ID>) {
        update(appID) { archive in
            archive.suggestions.removeAll { !eventIDs.contains($0.eventID) }
            archive.dismissed.formIntersection(Set(archive.suggestions.map(\.id)))
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
