//
//  AnalyticsViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// One app's Analytics: which view shows, the period, and everything the
/// views draw, computed from the store's facts whenever one of them changes.
@MainActor
@Observable
final class AnalyticsViewModel {
    let app: StoreApp
    let store: AnalyticsStore
    let services: any AnalyticsServices

    var tab = AnalyticsTab.overview { didSet { tabChanged(from: oldValue) } }
    /// 7, 28 or 90.
    var days = 28 { didSet { if days != oldValue { recompute() } } }
    /// The step whose rate the chart shows.
    var stage = FunnelStage.pageViews { didSet { if stage != oldValue { recomputeChart() } } }
    var dimension = BreakdownDimension.territory {
        didSet {
            guard dimension != oldValue else { return }
            selectedRowID = nil
            recomputeTable()
        }
    }

    var subscriptionsPane = SubscriptionsPane.summary
    /// Reports from Apple: which newer reports are ready, empty or asked.
    var isReportsPresented = false
    var columnGroup = BreakdownColumnGroup.funnel {
        didSet {
            guard columnGroup != oldValue else { return }
            if !sortColumn.isShown(in: columnGroup) { sortColumn = .downloads }
        }
    }

    var sortColumn = BreakdownColumn.impressions
    var sortAscending = false
    var selectedRowID: BreakdownRow.ID?
    var findingsFilter = FindingsFilter.open
    var selectedChangeID: MeasuredChange.ID?
    /// Break It Down opened from the Overview's Proceeds number: the
    /// banner saying where the amount comes from shows (closable) and the
    /// Proceeds column is highlighted.
    var showsProceedsBanner = false
    var isSettingsPresented = false
    var settingsFocus: AnalyticsSettingsFocus?
    /// The key Atlas is using, to name it where its role matters.
    var keyID: String?
    /// Logs a write the person confirmed here (Billing Grace Period) in
    /// History; the section connects it to the push history.
    @ObservationIgnored var onWrite: (PushRecord) -> Void = { _ in }

    private(set) var sellsSubscriptions = true
    private(set) var context = AnalyticsContext.empty
    private(set) var changes: [MeasuredChange] = []
    private(set) var dataset: AnalyticsDataset
    private(set) var funnel: FunnelReport?
    private(set) var chart: FunnelChart?
    private(set) var table: BreakdownTable?
    private(set) var subscriptions: SubscriptionsReport?
    private(set) var results: [MeasuredChange.ID: ChangeResult] = [:]
    private(set) var retention: RetentionReport?
    private(set) var lifecycle: LifecycleReport?
    private(set) var stability: StabilityReport?
    private(set) var afterDownload: AfterDownloadNumbers?
    private(set) var webPreview: WebPreviewReport?

    init(app: StoreApp, store: AnalyticsStore, services: any AnalyticsServices) {
        self.app = app
        self.store = store
        self.services = services
        dataset = store.dataset(for: app, sellsSubscriptions: true)
        recompute()
    }

    // MARK: - State

    var setup: AnalyticsSetup { store.setup(for: app.id) }
    var activity: AnalyticsActivity { store.activity(for: app.id) }
    var findings: AnalyticsFindingsState { store.findings(for: app.id) }
    /// When Apple's reports were last looked for, and when Apple was asked.
    var lastChecked: Date? { store.record(for: app.id).lastChecked }
    var askedOn: Date? { store.record(for: app.id).askedOn }

    /// The first download for an app that has nothing to show yet.
    var isLoadingFirstData: Bool { activity.isLoading && funnel == nil && setup == .ready }

    var tabs: [AnalyticsTab] {
        AnalyticsTab.allCases.filter { tab in
            switch tab {
            case .subscriptions: sellsSubscriptions
            case .stability: stability != nil
            default: true
            }
        }
    }

    var period: AnalyticsPeriod? { funnel?.period ?? reportsPeriod }

    /// The newer reports for this app.
    var reports: ReportsArchive { dataset.reports }

    /// The period the newer reports cover when the funnel has none yet.
    private var reportsPeriod: AnalyticsPeriod? {
        let last = AppleReportKind.allCases.compactMap { dataset.reports.lastDay($0) }.max()
        return last.map { AnalyticsPeriod(ending: $0, length: days) }
    }

    /// Apple is still making some of the newer reports for an app that has
    /// the funnel: the first-read banner.
    var preparingReports: [AppleReportKind] {
        guard setup == .ready, dataset.reports.firstChecked != nil else { return [] }
        return dataset.reports.pending
    }

    var gracePeriod: GracePeriodSetting? { dataset.gracePeriod }
    var staleDays: Int? { store.staleDays(through: dataset.through) }

    var sortedRows: [BreakdownRow] {
        table?.sorted(by: sortColumn, ascending: sortAscending) ?? []
    }

    var selectedRow: BreakdownRow? { table?.row(selectedRowID) }

    var selectedChange: MeasuredChange? {
        changes.first { $0.id == selectedChangeID } ?? changes.first
    }

    /// Open findings, the ones acted on taken out.
    var openFindings: [AnalyticsFinding] {
        findings.open.filter { actedResult(for: $0) == nil }
    }

    var actedFindings: [AnalyticsFinding] {
        findings.open.filter { actedResult(for: $0) != nil }
    }

    /// The change pushed in a finding's area after the person followed it
    /// there: the finding's result.
    func actedChange(for finding: AnalyticsFinding) -> MeasuredChange? {
        guard let acted = findings.actedOn[finding.id] else { return nil }
        return changes.last { $0.kind.area == finding.area && $0.date >= acted }
    }

    func actedResult(for finding: AnalyticsFinding) -> ChangeResult? {
        actedChange(for: finding).flatMap { results[$0.id] }
    }

    // MARK: - Inputs

    func configure(sellsSubscriptions: Bool, changes: [MeasuredChange]) {
        guard sellsSubscriptions != self.sellsSubscriptions || changes != self.changes else { return }
        self.sellsSubscriptions = sellsSubscriptions
        self.changes = changes
        if !tabs.contains(tab) { tab = .overview }
        recompute()
    }

    func setContext(_ context: AnalyticsContext) {
        guard context != self.context else { return }
        self.context = context
        recompute()
    }

    func sort(by column: BreakdownColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = column == .name
        }
    }

    func show(_ change: MeasuredChange.ID) {
        selectedChangeID = change
        tab = .afterChanges
    }

    func show(_ pane: SubscriptionsPane) {
        subscriptionsPane = pane
        tab = .subscriptions
    }

    func breakDown(by dimension: BreakdownDimension) {
        self.dimension = dimension
        tab = .breakDown
    }

    func openSettings(focus: AnalyticsSettingsFocus? = nil) {
        settingsFocus = focus
        isSettingsPresented = true
    }

    // MARK: - Apple

    func ask() async {
        await store.ask(for: app.id, services: services)
        recompute()
    }

    /// Downloads what's new when today's check hasn't happened, or always
    /// with `force` (Check Again, Refresh).
    func refresh(force: Bool = false) async {
        guard setup != .off, setup != .keyCannotAsk || force, force || store.isDue(app.id) else { return }
        await store.refresh(app.id, services: services)
        recompute()
    }

    /// Turns on Billing Grace Period, once the person confirmed it.
    func turnOnGracePeriod(_ duration: GracePeriodSetting.Duration) async throws {
        try await store.turnOnGracePeriod(for: app.id, duration: duration, services: services)
        onWrite(DirectWriteRecord.gracePeriod(appID: app.id, appName: app.name, duration: duration, date: store.now()))
        recompute()
    }

    /// After the vendor number changed: read sales again.
    func vendorNumberChanged() async {
        recompute()
        guard setup != .off else { return }
        store.setActivity(.loading(finished: 1), for: app.id)
        await store.refreshSales(services: services)
        store.setActivity(.idle, for: app.id)
        recompute()
    }

    // MARK: - Findings

    func dismiss(_ finding: AnalyticsFinding) {
        store.dismiss(finding, for: app.id)
    }

    func restore(_ finding: AnalyticsFinding.ID) {
        store.restore(finding, for: app.id)
    }

    /// The person followed `finding` to its section.
    func markActed(_ finding: AnalyticsFinding) {
        store.updateFindings({ state in
            if state.actedOn[finding.id] == nil { state.actedOn[finding.id] = self.store.now() }
        }, for: app.id)
    }

    // MARK: - Computing

    func recompute() {
        dataset = store.dataset(for: app, sellsSubscriptions: sellsSubscriptions)
        funnel = FunnelReport.make(dataset, days: days, changes: changes)
        if let funnel, funnel.step(stage) == nil || stage == .impressions, !isQuiet { stage = .pageViews }
        recomputeChart()
        recomputeTable()
        subscriptions = funnel.flatMap { SubscriptionsReport.make(dataset, period: $0.period) }
        let period = period
        retention = RetentionReport.make(dataset.reports, days: days)
        lifecycle = period.flatMap { LifecycleReport.make(dataset.reports, period: $0) }
        stability = StabilityReport.make(dataset.reports, now: AnalyticsDay(store.now()))
        afterDownload = period.map { AfterDownloadNumbers.make(dataset.reports, period: $0) }.flatMap { $0.isEmpty ? nil : $0 }
        webPreview = period.flatMap { WebPreviewReport.make(dataset.reports, period: $0) }
        if !tabs.contains(tab) { tab = .overview }
        results = Dictionary(
            changes.compactMap { change in ChangeResult.make(change, dataset: dataset, context: context).map { (change.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        guard setup == .ready, dataset.through != nil || !dataset.reports.isEmpty else { return }
        let fresh = FindingRules.findings(dataset, context: context, now: store.now())
        store.updateFindings({ $0.update(builtIn: fresh) }, for: app.id)
    }

    /// Too little traffic for rates: the chart shows impressions instead.
    private var isQuiet: Bool {
        if case .tooFew = funnel?.callout.kind { return true }
        return false
    }

    private func recomputeChart() {
        guard let funnel else {
            chart = nil
            return
        }
        chart = FunnelChart.make(dataset, report: funnel, stage: isQuiet ? .impressions : stage, changes: changes)
    }

    private func recomputeTable() {
        guard let funnel else {
            table = nil
            return
        }
        table = BreakdownTable.make(dataset, dimension: dimension, period: funnel.period, context: context)
    }

    private func tabChanged(from old: AnalyticsTab) {
        // Reading the findings clears the section's count.
        if tab == .whatToTry, old != .whatToTry { store.markFindingsSeen(for: app.id) }
    }
}
