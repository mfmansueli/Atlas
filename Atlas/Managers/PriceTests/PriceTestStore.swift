//
//  PriceTestStore.swift
//  Atlas
//

import Foundation
import Observation

/// Every app's price tests and the tests the assistant suggested (board
/// 76), kept per app in `Application Support/Atlas/Pricing` beside the
/// price history. A push marks a test running or ended; Pricing's sales
/// read keeps its 28 days for the verdict (`LivePricingSales`).
@MainActor
@Observable
final class PriceTestStore {
    static let shared = PriceTestStore(directory: sharedDirectory)

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return PriceChangeHistoryStore.defaultDirectory
    }

    private var books: [StoreApp.ID: PriceTestBook] = [:]
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var territories = TerritoryCatalog.standard

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func book(for appID: StoreApp.ID) -> PriceTestBook {
        if let book = books[appID] { return book }
        let book = fileURL(for: appID).flatMap(Self.read) ?? PriceTestBook()
        books[appID] = book
        return book
    }

    func tests(for appID: StoreApp.ID) -> [PriceTest] {
        book(for: appID).tests
    }

    /// Changes `appID`'s book, saving it when it changed.
    func update(_ appID: StoreApp.ID, _ change: (inout PriceTestBook) -> Void) {
        var book = book(for: appID)
        let before = book
        change(&book)
        guard book != before else { return }
        books[appID] = book
        if let url = fileURL(for: appID) { Self.write(book, to: url) }
    }

    /// A finished push: a test's start makes it run from the push day; its
    /// end ends it early, with no result.
    func record(push: PushRecord) {
        let readings = push.pushed.compactMap { PriceTestChanges.reading($0.id) }
        guard !readings.isEmpty else { return }
        let day = Calendar.gmtGregorian.startOfDay(for: push.date)
        update(push.appID) { book in
            for reading in readings {
                guard var test = book.test(id: reading.testID) else { continue }
                switch reading.kind {
                case .start:
                    guard test.state == .queued else { continue }
                    test.state = .running
                    test.startedOn = day
                case .end:
                    guard test.state == .running else { continue }
                    test.state = .endedEarly
                    test.endedOn = push.date
                }
                book.replace(test)
            }
        }
    }

    /// Finished tests of `productID` as HowSure reads them: each one's
    /// effect for every country of its region, the latest test first.
    func evidence(for appID: StoreApp.ID, productID: String) -> [String: PriceTestEvidence] {
        Self.evidence(book(for: appID).tests.filter { $0.productID == productID }, catalog: territories)
    }

    static func evidence(_ tests: [PriceTest], catalog: TerritoryCatalog = .standard) -> [String: PriceTestEvidence] {
        var result: [String: PriceTestEvidence] = [:]
        let finished = tests.compactMap { PriceTestEvidence($0) }.sorted { $0.endedOn < $1.endedOn }
        for evidence in finished {
            for territory in catalog.territories(in: evidence.region) {
                result[territory.id] = evidence
            }
        }
        return result
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole book at once.
    func load(_ book: PriceTestBook, for appID: StoreApp.ID) {
        books[appID] = book
    }
    #endif

    // MARK: - Files

    private func fileURL(for appID: StoreApp.ID) -> URL? {
        directory?.appending(path: "price-tests-\(appID).json")
    }

    private static func read(_ url: URL) -> PriceTestBook? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PriceTestBook.self, from: data)
    }

    private static func write(_ book: PriceTestBook, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(book).write(to: url, options: .atomic)
    }
}
