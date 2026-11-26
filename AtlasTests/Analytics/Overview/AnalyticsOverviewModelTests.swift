//
//  AnalyticsOverviewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Overview and the strip over the sample account's Lumen (DEBUG data).
@MainActor
@Suite("Analytics · the Overview from the view model")
struct AnalyticsOverviewModelTests {
    private typealias AppIDs = DebugFixtures.AppID

    private func model(_ appID: StoreApp.ID = AppIDs.lumen, store: AnalyticsStore? = nil) -> AnalyticsViewModel {
        let app = DebugFixtures.apps.first { $0.id == appID } ?? DebugFixtures.lumen
        let model = AnalyticsViewModel(app: app, store: store ?? DebugAnalyticsData.store(), services: DebugAnalyticsServices())
        model.configure(sellsSubscriptions: appID != AppIDs.tempo, changes: ChangeLog.changes(for: appID, in: DebugAnalyticsData.pushRecords))
        model.setContext(DebugAnalyticsData.context)
        return model
    }

    @Test func lumensOverviewCardSaysTheStepThatFell() {
        let model = model()
        let summary = model.summary(for: .overview)
        #expect(summary.text.hasPrefix(AnalyticsTabSummary.fewer(.pageViews)))
        #expect(summary.tone == .warning)
        #expect(model.summary(for: .afterChanges).text.hasPrefix("5 pushes"))
    }

    @Test func theFunnelHasFiveCardsAndANoteOnceSalesAreIn() {
        let model = model()
        #expect(model.funnelSteps.map(\.stage) == FunnelStage.allCases)
        #expect(model.funnelSteps.first { $0.stage == .pageViews }?.verdict == .worse)
        #expect(model.funnelNote?.hasPrefix("Paid starts: converted trials plus direct subscriptions.") == true)
        let first = model.funnelSteps[1]
        model.select(model.funnelSteps[3])
        #expect(model.chart?.stage == .trials)
        #expect(first.stage == .pageViews)
    }

    @Test func theNumbersLeadToTheirViews() {
        let model = model()
        let numbers = model.kpis(rating: nil, isRatingLoading: false)
        #expect(numbers.map(\.kind) == [.rating, .proceeds, .subscribers, .crashes])
        let crashes = numbers[3]
        #expect(crashes.tone == (model.stability?.isWorse == true ? .warning : .neutral))
        #expect(!model.open(.rating), "Rating leaves Analytics for Ratings & Reviews")
        #expect(model.open(.subscribers))
        #expect(model.tab == .subscriptions)
        #expect(model.open(.crashes))
        #expect(model.tab == .stability)
        #expect(model.open(.proceeds))
        #expect(model.tab == .breakDown)
        #expect(model.showsProceedsBanner)
    }

    @Test func lastPushIsTheNewestChange() throws {
        let model = model()
        let last = try #require(model.lastPush)
        let newest = try #require(model.changes.max { $0.date < $1.date })
        #expect(last.changeID == newest.id)
        #expect(last.detail.hasPrefix("Pushed \(AnalyticsText.day(newest.date))"))
    }

    @Test func withoutTheVendorNumberTheNoticeAsksForIt() async {
        let model = model(store: DebugAnalyticsData.store(vendorNumber: "", hasSales: false))
        #expect(model.notice == .missingVendorNumber)
        #expect(model.funnelNote == nil)
        let proceeds = model.kpis(rating: nil, isRatingLoading: false).first { $0.kind == .proceeds }
        #expect(proceeds?.value == "—")
        await model.handle(.addVendorNumber)
        #expect(model.isSettingsPresented)
        #expect(model.settingsFocus == .vendorNumber)
    }

    @Test func theStoreKnowsTheSameAvailabilityWithoutTheViewModel() {
        let store = DebugAnalyticsData.store()
        let model = model(store: store)
        #expect(store.availability(for: AppIDs.lumen) == model.availability)
        #expect(store.findingsBadgeCount(for: AppIDs.lumen) == store.newFindingCount(for: AppIDs.lumen))
    }

    @Test func beforeTheFirstReportsThereIsNoBadge() {
        let store = DebugAnalyticsData.store(hasSales: false)
        store.load(appID: AppIDs.lumen, record: AnalyticsAppRecord())
        #expect(store.availability(for: AppIDs.lumen) == .notSetUp)
        #expect(store.findingsBadgeCount(for: AppIDs.lumen) == 0)
    }
}
#endif
