//
//  AnalyticsStore.swift
//  Atlas
//

import Foundation
import Observation

/// Analytics' data on this Mac: each app's downloaded facts, the vendor's
/// sales, the settings and the findings' state. Kept as JSON in Application
/// Support when given a directory; in memory otherwise (tests, DEBUG
/// scenes). Everything is computed locally from it; nothing here writes to
/// App Store Connect.
@MainActor
@Observable
final class AnalyticsStore {
    static let shared = AnalyticsStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Analytics")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private(set) var settings = AnalyticsSettings()
    private(set) var sales = SalesArchive()
    private(set) var activity: [StoreApp.ID: AnalyticsActivity] = [:]
    /// Apps whose first reports arrived since the person last looked, for
    /// the window's toast.
    private(set) var arrivals: [StoreApp.ID] = []
    /// What went wrong reading sales that isn't the key's role, e.g. a
    /// vendor number Apple doesn't know.
    private(set) var salesError: String?
    /// Sales and Trends was asked for since launch. A Mac that never read a
    /// day of sales asks again at the next launch, not the next day.
    var askedForSalesThisLaunch = false
    /// What went wrong reading the newer reports; the funnel still shows.
    var reportsError: String?

    /// The app's Billing Grace Period, read with the reports; nil until read.
    private(set) var gracePeriods: [StoreApp.ID: GracePeriodSetting] = [:]

    private var archives: [StoreApp.ID: EngagementArchive] = [:]
    private var reportArchives: [StoreApp.ID: ReportsArchive] = [:]
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }

    init(directory: URL? = nil) {
        self.directory = directory
        guard let directory else { return }
        settings = Self.read(AnalyticsSettings.self, at: directory.appending(path: "settings.json")) ?? AnalyticsSettings()
        sales = Self.read(SalesArchive.self, at: directory.appending(path: "sales.json")) ?? SalesArchive()
    }

    // MARK: - Reading

    func record(for appID: StoreApp.ID) -> AnalyticsAppRecord {
        settings.records[appID] ?? AnalyticsAppRecord()
    }

    func archive(for appID: StoreApp.ID) -> EngagementArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(EngagementArchive.self, at: $0.appending(path: "engagement-\(appID).json")) } ?? EngagementArchive()
        archives[appID] = archive
        return archive
    }

    /// The newer reports (retention, subscribers by page, crashes…).
    func reports(for appID: StoreApp.ID) -> ReportsArchive {
        if let archive = reportArchives[appID] { return archive }
        let archive = directory.flatMap { Self.read(ReportsArchive.self, at: $0.appending(path: "reports-\(appID).json")) } ?? ReportsArchive()
        reportArchives[appID] = archive
        return archive
    }

    func setup(for appID: StoreApp.ID) -> AnalyticsSetup {
        let record = record(for: appID)
        if record.keyCannotAsk { return .keyCannotAsk }
        guard let asked = record.askedOn else { return .off }
        let hasSales = sales.events.contains { $0.appID == appID }
        return archive(for: appID).isEmpty && !hasSales && reports(for: appID).isEmpty ? .waiting(asked: asked) : .ready
    }

    var salesState: SalesState {
        if settings.vendorNumber.isEmpty { return .needsVendorNumber }
        if settings.keyCannotReadSales { return .keyCannotRead }
        return sales.days.isEmpty ? .waiting : .ready
    }

    /// Everything known about `app`, for the views to compute from.
    func dataset(for app: StoreApp, sellsSubscriptions: Bool) -> AnalyticsDataset {
        let archive = archive(for: app.id)
        return AnalyticsDataset(
            appID: app.id,
            appName: app.name,
            engagement: archive.facts,
            pages: archive.pageFacts,
            events: sales.events.filter { $0.appID == app.id },
            subscribers: sales.subscribers.filter { $0.appID == app.id },
            active: sales.active.filter { $0.appID == app.id },
            reports: reports(for: app.id),
            gracePeriod: gracePeriods[app.id],
            engagementState: archive.isEmpty ? .waiting(asked: record(for: app.id).askedOn) : .ready,
            salesState: salesState,
            sellsSubscriptions: sellsSubscriptions
        )
    }

    func activity(for appID: StoreApp.ID) -> AnalyticsActivity {
        activity[appID] ?? .idle
    }

    func findings(for appID: StoreApp.ID) -> AnalyticsFindingsState {
        settings.findings[appID] ?? AnalyticsFindingsState()
    }

    /// New findings to read, for the section's gray count.
    func newFindingCount(for appID: StoreApp.ID) -> Int {
        guard setup(for: appID) == .ready else { return 0 }
        return findings(for: appID).newCount
    }

    // MARK: - Settings

    func setVendorNumber(_ number: String) {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != settings.vendorNumber else { return }
        settings.vendorNumber = trimmed
        // Another vendor's sales aren't this one's.
        settings.keyCannotReadSales = false
        salesError = nil
        sales = SalesArchive()
        save()
        saveSales()
    }

    func setRefreshMode(_ mode: AnalyticsRefreshMode) {
        settings.refreshMode = mode
        save()
    }

    // MARK: - Findings

    func updateFindings(_ change: (inout AnalyticsFindingsState) -> Void, for appID: StoreApp.ID) {
        var state = findings(for: appID)
        change(&state)
        guard state != settings.findings[appID] else { return }
        settings.findings[appID] = state
        save()
    }

    /// An assistant's finding, from `add_finding`; one with the same id
    /// replaces the earlier one.
    func add(_ finding: AnalyticsFinding, for appID: StoreApp.ID) {
        updateFindings({ state in
            state.fromAssistants.removeAll { $0.id == finding.id }
            state.fromAssistants.insert(finding, at: 0)
            state.dismissed.removeAll { $0.id == finding.id }
            state.seen.remove(finding.id)
        }, for: appID)
    }

    func dismiss(_ finding: AnalyticsFinding, for appID: StoreApp.ID) {
        updateFindings({ state in
            state.dismissed.removeAll { $0.id == finding.id }
            state.dismissed.insert(DismissedFinding(finding: finding, date: now()), at: 0)
        }, for: appID)
    }

    func restore(_ id: AnalyticsFinding.ID, for appID: StoreApp.ID) {
        updateFindings({ $0.dismissed.removeAll { $0.id == id } }, for: appID)
    }

    func markFindingsSeen(for appID: StoreApp.ID) {
        updateFindings({ state in state.seen.formUnion(state.open.map(\.id)) }, for: appID)
    }

    func consumeArrivals() -> [StoreApp.ID] {
        defer { arrivals = [] }
        return arrivals
    }

    // MARK: - Changing (used by the refresh)

    func update(_ appID: StoreApp.ID, _ change: (inout AnalyticsAppRecord) -> Void) {
        var record = record(for: appID)
        change(&record)
        settings.records[appID] = record
        save()
    }

    func setActivity(_ value: AnalyticsActivity, for appID: StoreApp.ID) {
        activity[appID] = value
    }

    func apply(_ batches: [EngagementBatch], to appID: StoreApp.ID) {
        guard !batches.isEmpty else { return }
        var archive = archive(for: appID)
        let wasEmpty = archive.isEmpty
        archive.apply(batches)
        archives[appID] = archive
        if let directory { Self.write(archive, to: directory.appending(path: "engagement-\(appID).json")) }
        if wasEmpty, !archive.isEmpty, !record(for: appID).announcedArrival {
            update(appID) { $0.announcedArrival = true }
            arrivals.append(appID)
        }
    }

    func apply(_ download: ReportsDownload, to appID: StoreApp.ID) {
        var archive = reports(for: appID)
        archive.apply(download, now: now())
        guard archive != reportArchives[appID] else { return }
        reportArchives[appID] = archive
        if let directory { Self.write(archive, to: directory.appending(path: "reports-\(appID).json")) }
    }

    func setGracePeriod(_ setting: GracePeriodSetting?, for appID: StoreApp.ID) {
        gracePeriods[appID] = setting
    }

    func apply(_ download: SalesDownload) {
        sales.apply(download)
        saveSales()
    }

    func setSalesProblem(keyCannotRead: Bool, error: String?) {
        salesError = error
        guard settings.keyCannotReadSales != keyCannotRead else { return }
        settings.keyCannotReadSales = keyCannotRead
        save()
    }

    /// Forgets what was asked for `appID`; what's downloaded stays.
    func turnOff(_ appID: StoreApp.ID) {
        update(appID) { record in
            record.askedOn = nil
            record.announcedArrival = false
        }
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole state at once.
    func load(
        appID: StoreApp.ID, record: AnalyticsAppRecord, archive: EngagementArchive = EngagementArchive(),
        findings: AnalyticsFindingsState = AnalyticsFindingsState(), reports: ReportsArchive = ReportsArchive(),
        gracePeriod: GracePeriodSetting? = nil
    ) {
        settings.records[appID] = record
        settings.findings[appID] = findings
        archives[appID] = archive
        reportArchives[appID] = reports
        gracePeriods[appID] = gracePeriod
    }

    func load(sales: SalesArchive, vendorNumber: String, keyCannotReadSales: Bool = false) {
        self.sales = sales
        settings.vendorNumber = vendorNumber
        settings.keyCannotReadSales = keyCannotReadSales
    }
    #endif

    // MARK: - Files

    private func save() {
        guard let directory else { return }
        Self.write(settings, to: directory.appending(path: "settings.json"))
    }

    private func saveSales() {
        guard let directory else { return }
        Self.write(sales, to: directory.appending(path: "sales.json"))
    }

    private static func read<Value: Decodable>(_ type: Value.Type, at url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private static func write(_ value: some Encodable, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(value).write(to: url, options: .atomic)
    }
}
