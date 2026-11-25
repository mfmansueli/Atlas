//
//  WatchCenter.swift
//  Atlas
//

import Foundation
import Observation

/// Look for Improvements: an assistant that looks at the person's apps
/// from time to time and leaves suggestions in Atlas, without being a
/// nuisance. On every hourly check Atlas's own detectors (free, no AI) look
/// at what the check already read (`WatchDetectors`); the ledger keeps
/// each finding's state so nothing is asked twice (`WatchLedger`); and,
/// with the switch on and Pro, within the budget (`WatchBudget`), one
/// Claude Code run per app takes the findings left (`+Running`). What the
/// person makes of them stretches or pauses each kind (`+Outcomes`,
/// `WatchBackoff`). Every run is kept in a History; none ever pushes.
///
/// Each app's record is `watch-<appID>.json` in Application Support; in
/// memory in tests and DEBUG scenes.
@MainActor
@Observable
final class WatchCenter {
    static let shared = WatchCenter(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Watch")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    /// Each app's record, as read so far.
    private(set) var archives: [StoreApp.ID: WatchArchive] = [:]
    /// What the last check found and decided.
    private(set) var lastPlan: WatchPlan?
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }
    @ObservationIgnored var calendar: Calendar = .current

    init(directory: URL? = nil) {
        self.directory = directory
    }

    var budget: WatchBudget { WatchBudget(calendar: calendar) }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> WatchArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? WatchArchive()
        archives[appID] = archive
        return archive
    }

    /// The app's runs, newest first.
    func history(for appID: StoreApp.ID) -> [WatchHistoryEntry] {
        archive(for: appID).history.reversed()
    }

    func record(_ identity: String, appID: StoreApp.ID) -> WatchRecord? {
        archive(for: appID).records[identity]
    }

    /// The kinds that paused after three dismissals and wait for Keep
    /// Suggesting?.
    func kindsAskingKeepSuggesting(for appID: StoreApp.ID) -> [WatchSignalKind] {
        let archive = archive(for: appID)
        return WatchSignalKind.allCases.filter { archive.stats(for: $0).asksKeepSuggesting }
    }

    /// Every run started so far in the apps read, for the day's budget.
    var runStarts: [(appID: StoreApp.ID, date: Date)] {
        archives.values.flatMap(\.history).map { ($0.appID, $0.startedAt) }
    }

    // MARK: - What the person decides

    /// Not Now: it waits a week.
    func notNow(_ identity: String, appID: StoreApp.ID) {
        let until = now().addingTimeInterval(WatchLedger.snoozeTime)
        update(appID) { WatchLedger.decide(identity, .snoozed(until: until), in: &$0) }
    }

    /// Don't Suggest This Again: the kind, in this app.
    func dontSuggestAgain(_ kind: WatchSignalKind, appID: StoreApp.ID) {
        update(appID) { $0.updateStats(for: kind) { $0.isSilenced = true } }
    }

    func accept(_ identity: String, appID: StoreApp.ID) {
        let date = now()
        update(appID) { WatchLedger.decide(identity, .accepted(date: date), in: &$0) }
    }

    func dismiss(_ identity: String, appID: StoreApp.ID) {
        let date = now()
        update(appID) { WatchLedger.decide(identity, .dismissed(date: date), in: &$0) }
    }

    /// Keep Suggesting?'s answer.
    func keepSuggesting(_ kind: WatchSignalKind, appID: StoreApp.ID, keeps: Bool) {
        update(appID) { $0.updateStats(for: kind) { WatchBackoff.keepSuggesting(keeps, stats: &$0) } }
    }

    // MARK: - What a run sends

    /// A run's call that proposed something (`MCPServerController.onOriginProposal`):
    /// kept on its History entry.
    func noteProposal(origin: ChangeOrigin, tool: String, lines: [MCPToolOutcome.LogLine]) {
        guard let runID = origin.watchRunID,
              let appID = archives.first(where: { $0.value.history.contains { $0.id == runID } })?.key
        else { return }
        let date = now()
        let proposals = lines.filter { $0.outcome == .proposed }.map { WatchProposal(tool: tool, target: $0.target, date: date) }
        guard !proposals.isEmpty else { return }
        update(appID) { $0.updateEntry(runID) { $0.proposals += proposals } }
    }

    // MARK: - Files

    func update(_ appID: StoreApp.ID, _ change: (inout WatchArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        Self.write(archive, to: Self.file(appID, in: directory))
    }

    func setLastPlan(_ plan: WatchPlan) {
        lastPlan = plan
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole record at once.
    func load(_ archive: WatchArchive, for appID: StoreApp.ID) {
        archives[appID] = archive
    }
    #endif

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "watch-\(appID).json")
    }

    private static func read(at url: URL) -> WatchArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchArchive.self, from: data)
    }

    private static func write(_ archive: WatchArchive, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: url, options: .atomic)
    }
}
