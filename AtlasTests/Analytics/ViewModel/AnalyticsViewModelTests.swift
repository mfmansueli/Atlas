//
//  AnalyticsViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Analytics · the view model")
struct AnalyticsViewModelTests {
    private typealias AppIDs = DebugFixtures.AppID

    private func model(
        _ appID: StoreApp.ID = AppIDs.lumen, store: AnalyticsStore? = nil, services: any AnalyticsServices = DebugAnalyticsServices()
    ) -> AnalyticsViewModel {
        let app = DebugFixtures.apps.first { $0.id == appID } ?? DebugFixtures.lumen
        let model = AnalyticsViewModel(app: app, store: store ?? DebugAnalyticsData.store(), services: services)
        model.configure(sellsSubscriptions: appID != AppIDs.tempo, changes: ChangeLog.changes(for: appID, in: DebugAnalyticsData.pushRecords))
        model.setContext(DebugAnalyticsData.context)
        return model
    }

    @Test func lumenOpensOnItsFunnelWithTheSampleStory() throws {
        let model = model()
        #expect(model.setup == .ready)
        #expect(model.tabs == AnalyticsTab.allCases)
        let funnel = try #require(model.funnel)
        #expect(funnel.days == 28)
        #expect(funnel.period.last == DebugAnalyticsData.through)
        // The new screenshots on Oct 21 cost tap-through.
        #expect(funnel.callout.kind == .loss(.pageViews))
        #expect(funnel.callout.actions.contains(.breakDown(.source)))
        #expect(model.chart?.stage == .pageViews)
        #expect(model.chart?.marks.count == 4)
        #expect(model.changes.count == 5)
        #expect(model.subscriptions != nil)
        #expect(model.staleDays == nil)
    }

    @Test func thePeriodAndTheChartedStepFollowThePerson() {
        let model = model()
        model.days = 90
        #expect(model.funnel?.period.length == 90)
        #expect(model.chart?.points.count == 180)
        model.stage = .trials
        #expect(model.chart?.stage == .trials)
        model.days = 7
        #expect(model.funnel?.previous?.length == 7)
        #expect(model.table?.period.length == 7)
    }

    @Test func theBreakdownSortsAndSelects() {
        let model = model()
        model.breakDown(by: .source)
        #expect(model.tab == .breakdown)
        #expect(model.table?.dimension == .source)
        #expect(model.sortedRows.first?.id == "App Store Search")
        model.dimension = .territory
        model.selectedRowID = "DE"
        #expect(model.selectedRow?.name == "Germany")
        model.sort(by: .downloadRate)
        #expect(model.sortColumn == .downloadRate)
        #expect(!model.sortAscending)
        model.sort(by: .downloadRate)
        #expect(model.sortAscending)
        model.sort(by: .name)
        #expect(model.sortedRows.first?.name == "Brazil")
        // Another split has other rows: the selection goes.
        model.dimension = .device
        #expect(model.selectedRowID == nil)
    }

    @Test func findingsAreWorkedOutAndReadingThemClearsTheCount() throws {
        let store = DebugAnalyticsData.store()
        let model = model(store: store)
        let ids = model.openFindings.map(\.id)
        #expect(ids.first == "assistant.search-tap-through")
        #expect(ids.contains("step.pageViews"))
        #expect(ids.contains("territory.downloads.DE"))
        #expect(store.newFindingCount(for: AppIDs.lumen) == ids.count)
        model.tab = .findings
        #expect(store.newFindingCount(for: AppIDs.lumen) == 0)

        let germany = try #require(model.openFindings.first { $0.id == "territory.downloads.DE" })
        model.dismiss(germany)
        #expect(!model.openFindings.contains(germany))
        #expect(model.findings.dismissed.map(\.id) == ["territory.downloads.DE"])
        model.restore(germany.id)
        #expect(model.openFindings.contains { $0.id == germany.id })
    }

    @Test func aFindingFollowedToItsSectionMovesToActedOnOnceSomethingWasPushedThere() throws {
        let store = DebugAnalyticsData.store()
        let model = model(store: store)
        let germany = try #require(model.openFindings.first { $0.id == "territory.downloads.DE" })
        #expect(model.actedFindings.isEmpty)
        // Followed on Sep 30; the subtitle went out on Oct 2.
        store.updateFindings({ $0.actedOn[germany.id] = DebugAnalyticsData.date(month: 9, day: 30) }, for: AppIDs.lumen)
        #expect(model.actedFindings.map(\.id) == [germany.id])
        #expect(model.actedChange(for: germany)?.kind == .searchText)
        #expect(model.actedResult(for: germany)?.state == .final)
        #expect(!model.openFindings.contains { $0.id == germany.id })
        // Followed today: nothing pushed since, so it stays open.
        let step = try #require(model.openFindings.first { $0.id == "step.pageViews" })
        model.markActed(step)
        #expect(model.openFindings.contains { $0.id == step.id })
    }

    @Test func changesAreMeasuredAndPricesAreLeftToPricing() throws {
        let model = model()
        let kinds = model.changes.map(\.kind)
        #expect(kinds == [.inAppTexts, .prices, .screenshots, .searchText, .searchText])
        let screenshots = try #require(model.changes.first { $0.kind == .screenshots })
        #expect(model.results[screenshots.id]?.state == .measuring(day: 20, ends: DebugAnalyticsData.date(month: 11, day: 17, hour: 0)))
        let prices = try #require(model.changes.first { $0.kind == .prices })
        #expect(model.results[prices.id] == nil)
        model.show(screenshots.id)
        #expect(model.tab == .changes)
        #expect(model.selectedChange?.id == screenshots.id)
    }

    @Test func anAppWithoutASubscriptionHasNoSubscriptionsView() {
        let model = model(AppIDs.tempo)
        #expect(!model.tabs.contains(.subscriptions))
        #expect(model.funnel?.steps.count == 3)
        #expect(model.subscriptions == nil)
    }

    @Test func aNewAppAndAQuietOne() {
        let parcel = model(AppIDs.parcel)
        #expect(parcel.funnel?.isNew == true)
        #expect(parcel.openFindings.isEmpty)
        let quiet = model(AppIDs.quiet)
        #expect(quiet.funnel?.callout.kind == .tooFew)
        // Rates mean nothing there: impressions are charted instead.
        #expect(quiet.chart?.stage == .impressions)
    }

    @Test func askingAndTheSetupStates() async {
        let store = DebugAnalyticsData.store()
        let fieldnote = model(AppIDs.fieldnote, store: store)
        #expect(fieldnote.setup == .off)
        #expect(fieldnote.funnel == nil)
        await fieldnote.ask()
        #expect(fieldnote.setup == .waiting(asked: DebugAnalyticsData.today))

        let refused = model(AppIDs.fieldnote, store: DebugAnalyticsData.store(), services: DebugAnalyticsServices(keyCannotAsk: true))
        await refused.ask()
        #expect(refused.setup == .keyCannotAsk)
    }

    @Test func withoutTheVendorNumberTheFunnelStopsAtDownloadsAndSaysWhy() {
        let model = model(store: DebugAnalyticsData.store(vendorNumber: "", hasSales: false))
        #expect(model.funnel?.step(.trials)?.gap == .needsVendorNumber)
        #expect(model.funnel?.noteIsWarning == true)
        #expect(model.subscriptions == nil)
        model.openSettings(focus: .vendorNumber)
        #expect(model.isSettingsPresented)
        #expect(model.settingsFocus == .vendorNumber)
    }

    @Test func refreshOnlyDownloadsWhenTodaysCheckHasntHappened() async {
        let services = FakeAnalyticsServices()
        let store = DebugAnalyticsData.store()
        let model = model(store: store, services: services)
        await model.refresh()
        #expect(services.knownInstances.isEmpty)
        await model.refresh(force: true)
        #expect(services.knownInstances.count == 1)
    }
}
#endif
