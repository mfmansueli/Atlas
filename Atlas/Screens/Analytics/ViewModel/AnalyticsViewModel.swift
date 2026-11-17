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

    var tab = AnalyticsTab.funnel { didSet { tabChanged(from: oldValue) } }
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

    var sortColumn = BreakdownColumn.impressions
    var sortAscending = false
    var selectedRowID: BreakdownRow.ID?
    var findingsFilter = FindingsFilter.open
    var selectedChangeID: MeasuredChange.ID?
    var isSettingsPresented = false
    var settingsFocus: AnalyticsSettingsFocus?
    /// The key Atlas is using, to name it where its role matters.
    var keyID: String?

    private(set) var sellsSubscriptions = true
    private(set) var context = AnalyticsContext.empty
    private(set) var changes: [MeasuredChange] = []
    private(set) var dataset: AnalyticsDataset
    private(set) var funnel: FunnelReport?
    private(set) var chart: FunnelChart?
    private(set) var table: BreakdownTable?
    private(set) var subscriptions: SubscriptionsReport?
    private(set) var results: [MeasuredChange.ID: ChangeResult] = [:]

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
        AnalyticsTab.allCases.filter { $0 != .subscriptions || sellsSubscriptions }
    }

    var period: AnalyticsPeriod? { funnel?.period }
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
        if !tabs.contains(tab) { tab = .funnel }
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
        tab = .changes
    }

    func breakDown(by dimension: BreakdownDimension) {
        self.dimension = dimension
        tab = .breakdown
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
        results = Dictionary(
            changes.compactMap { change in ChangeResult.make(change, dataset: dataset, context: context).map { (change.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        guard setup == .ready, dataset.through != nil else { return }
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
        if tab == .findings, old != .findings { store.markFindingsSeen(for: app.id) }
    }
}
