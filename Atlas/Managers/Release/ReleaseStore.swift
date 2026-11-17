//
//  ReleaseStore.swift
//  Atlas
//

import Foundation
import Observation

/// What Atlas remembers about each app's version on its way to the
/// App Store: its last status (for the sidebar's footer and the checks
/// while it's with App Review), when each step was first seen, and the
/// In-App Events that go with it. JSON in Application Support when given a
/// directory; in memory otherwise (tests, DEBUG scenes).
@MainActor
@Observable
final class ReleaseStore {
    static let shared = ReleaseStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Release")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private(set) var archive = ReleaseArchive()
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }

    init(directory: URL? = nil) {
        self.directory = directory
        guard let directory, let data = try? Data(contentsOf: Self.file(in: directory)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        archive = (try? decoder.decode(ReleaseArchive.self, from: data)) ?? ReleaseArchive()
    }

    // MARK: - Status

    func snapshot(for appID: StoreApp.ID) -> ReleaseSnapshot? {
        archive.snapshots[appID]
    }

    /// The apps whose version is with App Review, approved or rolling out.
    var appsInFlight: [StoreApp.ID] {
        archive.snapshots.filter(\.value.phase.isInFlight).map(\.key).sorted()
    }

    /// Records what was just read. Returns the phase the version moved to
    /// since the last time (nil the first time, or when nothing changed),
    /// so the window can say so. Only a move seen here gets a date: a
    /// version found already live went live some day this Mac didn't see.
    @discardableResult
    func note(_ status: ReleaseStatus, for appID: StoreApp.ID) -> ReleasePhase? {
        let snapshot = ReleaseSnapshot(status)
        let previous = archive.snapshots[appID]
        let moved = previous.map { $0.versionID == snapshot.versionID && $0.phaseKey != snapshot.phaseKey } ?? false
        var updated = archive
        updated.snapshots[appID] = snapshot
        if moved, updated.seen[snapshot.versionID]?[snapshot.phaseKey] == nil {
            updated.seen[snapshot.versionID, default: [:]][snapshot.phaseKey] = now()
        }
        guard updated != archive else { return nil }
        archive = updated
        save()
        return moved ? status.phase : nil
    }

    /// When the version was first seen in a phase.
    func date(of phaseKey: String, versionID: String) -> Date? {
        archive.seen[versionID]?[phaseKey]
    }

    // MARK: - Events

    func eventIDs(for appID: StoreApp.ID) -> [String] {
        archive.eventsWithVersion[appID] ?? []
    }

    func setEventIDs(_ ids: [String], for appID: StoreApp.ID) {
        guard archive.eventsWithVersion[appID] ?? [] != ids else { return }
        archive.eventsWithVersion[appID] = ids.isEmpty ? nil : ids
        save()
    }

    #if DEBUG
    /// DEBUG scenes and tests: when a step was seen.
    func setDate(_ date: Date, of phaseKey: String, versionID: String) {
        archive.seen[versionID, default: [:]][phaseKey] = date
    }
    #endif

    // MARK: - File

    private func save() {
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: Self.file(in: directory), options: .atomic)
    }

    private static func file(in directory: URL) -> URL {
        directory.appending(path: "release.json")
    }
}
