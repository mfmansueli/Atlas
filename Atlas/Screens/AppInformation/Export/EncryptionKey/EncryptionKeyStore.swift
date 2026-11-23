//
//  EncryptionKeyStore.swift
//  Atlas
//

import Foundation
import Observation

/// The last `report_encryption_key` of each app. JSON in Application
/// Support when given a directory; in memory otherwise (tests, DEBUG
/// scenes). Export Compliance's card and `get_export_compliance` read it.
@MainActor
@Observable
final class EncryptionKeyStore {
    static let shared = EncryptionKeyStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/EncryptionKey")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private var reports: [StoreApp.ID: EncryptionKeyReport] = [:]
    /// Apps whose file was read (or found missing) this launch.
    @ObservationIgnored private var readApps: Set<StoreApp.ID> = []
    @ObservationIgnored private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func report(for appID: StoreApp.ID) -> EncryptionKeyReport? {
        if !readApps.contains(appID) {
            readApps.insert(appID)
            if let directory, let report = Self.read(at: Self.file(appID, in: directory)) { reports[appID] = report }
        }
        return reports[appID]
    }

    /// Keeps an assistant's report, replacing the one before.
    func setReport(_ report: EncryptionKeyReport) {
        readApps.insert(report.appID)
        guard reports[report.appID] != report else { return }
        reports[report.appID] = report
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(report).write(to: Self.file(report.appID, in: directory), options: .atomic)
    }

    func removeReport(for appID: StoreApp.ID) {
        readApps.insert(appID)
        reports[appID] = nil
        guard let directory else { return }
        try? FileManager.default.removeItem(at: Self.file(appID, in: directory))
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "key-\(appID).json")
    }

    private static func read(at url: URL) -> EncryptionKeyReport? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EncryptionKeyReport.self, from: data)
    }
}
