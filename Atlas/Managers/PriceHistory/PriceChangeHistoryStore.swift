//
//  PriceChangeHistoryStore.swift
//  Atlas
//

import Foundation
import Observation

/// Every app's price history (`PriceChangeHistory`), kept as JSON in
/// Application Support/Atlas/Pricing/price-history-<app>.json when given a
/// directory; in memory otherwise (unit tests, DEBUG scenes). Review & Push
/// records what it pushes, Pricing's reads what they find.
@MainActor
@Observable
final class PriceChangeHistoryStore {
    static let shared = PriceChangeHistoryStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Pricing")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private var histories: [StoreApp.ID: PriceChangeHistory] = [:]
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var territories = TerritoryCatalog.standard

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func history(for appID: StoreApp.ID) -> PriceChangeHistory {
        if let history = histories[appID] { return history }
        let history = fileURL(for: appID).flatMap(Self.read) ?? PriceChangeHistory()
        histories[appID] = history
        return history
    }

    /// Changes `appID`'s history, saving it when it changed.
    func update(_ appID: StoreApp.ID, _ change: (inout PriceChangeHistory) -> Void) {
        var history = history(for: appID)
        let before = history
        change(&history)
        guard history != before else { return }
        histories[appID] = history
        if let url = fileURL(for: appID) { Self.write(history, to: url) }
    }

    /// A finished push's subscription price changes.
    func record(push: PushRecord) {
        let records = PriceChangeHistory.records(in: push, territories: territories)
        guard !records.isEmpty else { return }
        update(push.appID) { $0.add(pushed: records) }
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole history at once.
    func load(_ history: PriceChangeHistory, for appID: StoreApp.ID) {
        histories[appID] = history
    }
    #endif

    // MARK: - Files

    private func fileURL(for appID: StoreApp.ID) -> URL? {
        directory?.appending(path: "price-history-\(appID).json")
    }

    private static func read(_ url: URL) -> PriceChangeHistory? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PriceChangeHistory.self, from: data)
    }

    private static func write(_ history: PriceChangeHistory, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(history).write(to: url, options: .atomic)
    }
}
