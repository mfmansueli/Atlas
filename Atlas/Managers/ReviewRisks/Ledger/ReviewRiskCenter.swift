//
//  ReviewRiskCenter.swift
//  Atlas
//

import Foundation

/// The App Review risks of every app: runs the checks (`check`), keeps
/// the last report per app, and remembers dismissals and what assistants
/// confirmed or cleared, in Application Support/Atlas/ReviewRisks.
@MainActor
@Observable
final class ReviewRiskCenter {
    static let shared = ReviewRiskCenter(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/ReviewRisks")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    /// A report younger than this is reused unless a refresh is asked for.
    static let freshness: TimeInterval = 10 * 60

    private var entries: [StoreApp.ID: ReviewRiskLedgerEntry] = [:]
    /// Apps whose check is running now.
    private(set) var checking: Set<StoreApp.ID> = []
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }

    init(directory: URL? = nil) {
        self.directory = directory
    }

    // MARK: - Reading

    func entry(for appID: StoreApp.ID) -> ReviewRiskLedgerEntry {
        if let entry = entries[appID] { return entry }
        let entry = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? ReviewRiskLedgerEntry()
        entries[appID] = entry
        return entry
    }

    /// The last report, with dismissals made since applied.
    func lastReport(for appID: StoreApp.ID) -> ReviewRiskReport? {
        let entry = entry(for: appID)
        guard var report = entry.lastReport else { return nil }
        let hidden = Set(entry.dismissed.keys).union(entry.cleared.keys)
        let before = report.risks.count
        report.risks.removeAll { hidden.contains($0.id) }
        report.dismissedCount += before - report.risks.count
        return report
    }

    func isFresh(_ appID: StoreApp.ID) -> Bool {
        guard let checked = entry(for: appID).lastReport?.checkedAt else { return false }
        return now().timeIntervalSince(checked) < Self.freshness
    }

    // MARK: - Checking

    /// Runs every check on `app` (or reuses a fresh report) and keeps it.
    @discardableResult
    func check(_ app: StoreApp, loader: ReviewRiskFactsLoader, refresh: Bool = false) async -> ReviewRiskReport {
        if !refresh, isFresh(app.id), let report = lastReport(for: app.id) { return report }
        checking.insert(app.id)
        defer { checking.remove(app.id) }
        let facts = await loader.facts(for: app)
        let report = ReviewRiskEngine.report(facts, versionString: facts.version?.versionString, ledger: entry(for: app.id))
        update(app.id) { $0.lastReport = report }
        return report
    }

    // MARK: - The person and assistants

    /// The person's Dismiss: it stays out of every list until it changes
    /// (a new subject gets a new ID).
    func dismiss(_ riskID: String, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed[riskID] = now() }
    }

    func restore(_ riskID: String, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed[riskID] = nil }
    }

    /// An assistant confirmed a risk in the project.
    func report(_ risk: ReviewRisk, for appID: StoreApp.ID) {
        update(appID) { entry in
            entry.reported[risk.id] = risk
            entry.cleared[risk.id] = nil
            if var last = entry.lastReport {
                last.risks.removeAll { $0.id == risk.id }
                last.risks.append(risk)
                last.risks.sort(by: ReviewRisk.ordered)
                last.notChecked.removeAll { $0.check == risk.check }
                entry.lastReport = last
            }
        }
    }

    /// An assistant read the project and the risk isn't there.
    func clear(_ verdict: ReviewRiskVerdict, for appID: StoreApp.ID) {
        update(appID) { entry in
            entry.cleared[verdict.riskID] = verdict
            entry.reported[verdict.riskID] = nil
            if var last = entry.lastReport {
                last.risks.removeAll { $0.id == verdict.riskID }
                last.notChecked.removeAll { $0.check == verdict.check }
                entry.lastReport = last
            }
        }
    }

    // MARK: - Saving

    private func update(_ appID: StoreApp.ID, _ change: (inout ReviewRiskLedgerEntry) -> Void) {
        var entry = entry(for: appID)
        change(&entry)
        entries[appID] = entry
        guard let directory else { return }
        Self.write(entry, to: Self.file(appID, in: directory))
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "\(appID).json")
    }

    private static func read(at url: URL) -> ReviewRiskLedgerEntry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReviewRiskLedgerEntry.self, from: data)
    }

    private static func write(_ entry: ReviewRiskLedgerEntry, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
