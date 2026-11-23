//
//  AnalyticsStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Analytics · the store and its refresh")
struct AnalyticsStoreTests {
    private typealias Data = AnalyticsTestData

    private let app = StoreApp(id: AnalyticsTestData.appID, name: "Lumen Journal", bundleID: "dev.northpier.lumen")
    private let today = AnalyticsTestData.through.adding(2).date.addingTimeInterval(9 * 3600)

    private func store(directory: URL? = nil) -> AnalyticsStore {
        let store = AnalyticsStore(directory: directory)
        store.now = { today }
        return store
    }

    private var batch: EngagementBatch {
        EngagementBatch(
            instanceID: "i1", kind: .engagement, isDetailed: false, processing: Data.through.adding(1),
            facts: [Data.fact(impressions: 100, views: 8)]
        )
    }

    // MARK: - Asking

    @Test func askingMovesFromOffToWaiting() async {
        let store = store()
        let services = FakeAnalyticsServices()
        #expect(store.setup(for: app.id) == .off)
        await store.ask(for: app.id, services: services)
        #expect(services.asked == [app.id])
        #expect(store.setup(for: app.id) == .waiting(asked: today))
        #expect(store.activity(for: app.id) == .idle)
    }

    @Test func aKeyThatIsntAdminIsItsOwnStateNotAnError() async {
        let store = store()
        let services = FakeAnalyticsServices()
        services.askError = AppStoreConnectError.forbidden(detail: nil)
        await store.ask(for: app.id, services: services)
        #expect(store.setup(for: app.id) == .keyCannotAsk)
        #expect(store.activity(for: app.id) == .idle)
        // With an Admin key the next try goes through.
        services.askError = nil
        await store.ask(for: app.id, services: services)
        #expect(store.setup(for: app.id) == .waiting(asked: today))
    }

    @Test func anotherFailureIsShown() async {
        let store = store()
        let services = FakeAnalyticsServices()
        services.askError = AppStoreConnectError.rateLimited
        await store.ask(for: app.id, services: services)
        #expect(store.setup(for: app.id) == .off)
        if case .failed = store.activity(for: app.id) {} else { Issue.record("The failure should be kept for the view") }
    }

    // MARK: - Refreshing

    @Test func theFirstReportsMakeItReadyAndAreAnnouncedOnce() async {
        let store = store()
        let services = FakeAnalyticsServices()
        await store.ask(for: app.id, services: services)
        await store.refresh(app.id, services: services)
        #expect(store.setup(for: app.id) == .waiting(asked: today))
        #expect(store.consumeArrivals().isEmpty)

        services.batches = [batch]
        await store.refresh(app.id, services: services)
        #expect(store.setup(for: app.id) == .ready)
        #expect(store.consumeArrivals() == [app.id])
        #expect(store.consumeArrivals().isEmpty)
        #expect(store.record(for: app.id).lastChecked == today)
        #expect(!store.isDue(app.id))

        // The next refresh says which instances it has already.
        await store.refresh(app.id, services: services)
        #expect(services.knownInstances.last == ["i1"])
        #expect(store.archive(for: app.id).facts.count == 1)
    }

    @Test func aRequestMadeElsewhereCountsAsAsked() async {
        let store = store()
        let services = FakeAnalyticsServices()
        services.batches = [batch]
        await store.refresh(app.id, services: services)
        #expect(store.setup(for: app.id) == .ready)
    }

    @Test func aRequestAppleStoppedTurnsAnalyticsOff() async {
        let store = store()
        let services = FakeAnalyticsServices()
        await store.ask(for: app.id, services: services)
        services.status = AnalyticsRequestStatus()
        await store.refresh(app.id, services: services)
        #expect(store.setup(for: app.id) == .off)
    }

    @Test func stoppingKeepsWhatWasDownloaded() async {
        let store = store()
        let services = FakeAnalyticsServices()
        services.batches = [batch]
        await store.ask(for: app.id, services: services)
        await store.refresh(app.id, services: services)
        #expect(await store.stop(for: app.id, services: services) == nil)
        #expect(services.stopped == [app.id])
        #expect(store.setup(for: app.id) == .off)
        #expect(store.archive(for: app.id).facts.count == 1)
    }

    // MARK: - Sales

    @Test func salesNeedTheVendorNumber() async {
        let store = store()
        let services = FakeAnalyticsServices()
        #expect(store.salesState == .needsVendorNumber)
        await store.refreshSales(services: services)
        #expect(services.salesDays.isEmpty)

        store.setVendorNumber(" 85012345 ")
        #expect(store.settings.vendorNumber == "85012345")
        #expect(store.salesState == .waiting)
        services.sales.events = [Data.event(.trialStart, 3)]
        await store.refreshSales(services: services)
        #expect(services.salesDays.first?.count == AnalyticsStore.salesHistoryDays)
        #expect(services.salesDays.first?.first == Data.through.adding(1))
        #expect(services.activeDays.first?.count == 4)
        #expect(store.salesState == .ready)
        #expect(store.dataset(for: app, sellsSubscriptions: true).events.count == 1)

        // Afterwards only the newest days are read again.
        await store.refreshSales(services: services)
        #expect(services.salesDays.last?.count == AnalyticsStore.salesRereadDays)
        #expect(services.activeDays.last?.count == 1)
    }

    @Test func aKeyThatCantReadSalesIsRemembered() async {
        let store = store()
        let services = FakeAnalyticsServices()
        store.setVendorNumber("85012345")
        services.salesError = AppStoreConnectError.forbidden(detail: nil)
        await store.refreshSales(services: services)
        #expect(store.salesState == .keyCannotRead)
        #expect(store.salesError == nil)
        services.salesError = AppStoreConnectError.server(statusCode: 400, detail: "Invalid vendor number")
        await store.refreshSales(services: services)
        #expect(store.salesError == "Sales didn’t load. Apple refused the request. See Details.\nDetails: HTTP 400 — Invalid vendor number")
        // Another vendor number starts over.
        store.setVendorNumber("85099999")
        #expect(store.salesState == .waiting)
        #expect(store.salesError == nil)
    }

    // MARK: - Dataset, findings, files

    @Test func theDatasetSaysWhatIsMissing() async {
        let store = store()
        let services = FakeAnalyticsServices()
        await store.ask(for: app.id, services: services)
        var dataset = store.dataset(for: app, sellsSubscriptions: true)
        #expect(dataset.engagementState == .waiting(asked: today))
        #expect(dataset.salesState == .needsVendorNumber)
        services.batches = [batch]
        await store.refresh(app.id, services: services)
        dataset = store.dataset(for: app, sellsSubscriptions: false)
        #expect(dataset.engagementState == .ready)
        #expect(dataset.through == Data.through)
        #expect(!dataset.sellsSubscriptions)
    }

    @Test func dataOlderThanUsualIsStale() {
        let store = store()
        #expect(store.staleDays(through: Data.through) == nil)
        #expect(store.staleDays(through: Data.through.adding(-3)) == 5)
        #expect(store.staleDays(through: nil) == nil)
    }

    @Test func findingsCanBeAddedDismissedRestoredAndSeen() async {
        let store = store()
        let services = FakeAnalyticsServices()
        services.batches = [batch]
        await store.refresh(app.id, services: services)
        let finding = AnalyticsFinding(
            id: "cc.1", source: .assistant("Claude Code"), title: "Search is weak", why: "", sureness: "Sure", surenessDetail: "",
            action: .screenshots(locale: nil)
        )
        store.add(finding, for: app.id)
        #expect(store.newFindingCount(for: app.id) == 1)
        store.markFindingsSeen(for: app.id)
        #expect(store.newFindingCount(for: app.id) == 0)
        store.dismiss(finding, for: app.id)
        #expect(store.findings(for: app.id).open.isEmpty)
        #expect(store.findings(for: app.id).dismissed.first?.date == today)
        store.restore(finding.id, for: app.id)
        #expect(store.findings(for: app.id).open.map(\.id) == ["cc.1"])
    }

    @Test func everythingIsKeptInItsDirectory() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: "analytics-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = store(directory: directory)
        let services = FakeAnalyticsServices()
        services.batches = [batch]
        services.sales.events = [Data.event(.trialStart, 3)]
        first.setVendorNumber("85012345")
        first.setRefreshMode(.whenOpened)
        await first.ask(for: app.id, services: services)
        await first.refresh(app.id, services: services)

        let second = store(directory: directory)
        #expect(second.settings.vendorNumber == "85012345")
        #expect(second.settings.refreshMode == .whenOpened)
        #expect(second.setup(for: app.id) == .ready)
        #expect(second.archive(for: app.id).facts.first?.impressions == 100)
        #expect(second.sales.events.count == 1)
        #expect(second.record(for: app.id).announcedArrival)
    }
}
