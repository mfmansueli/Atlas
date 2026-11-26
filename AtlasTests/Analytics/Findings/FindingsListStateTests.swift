//
//  FindingsListStateTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 92's What to Try states: new, waiting for a push, acted on,
/// dismissed, and none yet (with why).
@MainActor
@Suite("Analytics · What to Try states")
struct FindingsListStateTests {
    private typealias AppIDs = DebugFixtures.AppID

    private func model(_ appID: StoreApp.ID = AppIDs.lumen, store: AnalyticsStore = DebugAnalyticsData.store()) -> AnalyticsViewModel {
        let app = DebugFixtures.apps.first { $0.id == appID } ?? DebugFixtures.lumen
        let model = AnalyticsViewModel(app: app, store: store, services: DebugAnalyticsServices())
        model.configure(sellsSubscriptions: appID != AppIDs.tempo, changes: ChangeLog.changes(for: appID, in: DebugAnalyticsData.pushRecords))
        model.setContext(DebugAnalyticsData.context)
        return model
    }

    @Test func withoutAnyFindingTheStateSaysWhy() {
        let first = AnalyticsDay(number: 100)
        #expect(FindingsListState.make(dayCount: 9, firstDay: first, isQuiet: false, findingCount: 0) == .notYet(days: 9, firstOn: first.adding(28).date))
        #expect(FindingsListState.make(dayCount: 9, firstDay: nil, isQuiet: false, findingCount: 0) == .notYet(days: 9, firstOn: nil))
        #expect(FindingsListState.make(dayCount: 90, firstDay: first, isQuiet: true, findingCount: 0) == .tooQuiet)
        #expect(FindingsListState.make(dayCount: 90, firstDay: first, isQuiet: false, findingCount: 0) == .nothingStandsOut)
        // Any finding, even a dismissed one, shows the lists.
        #expect(FindingsListState.make(dayCount: 9, firstDay: first, isQuiet: true, findingCount: 1) == .list)
    }

    @Test func eachEmptyStateHasItsSentence() {
        let nov29 = DebugAnalyticsData.date(month: 11, day: 29)
        let notYet = FindingsListState.notYet(days: 9, firstOn: nov29)
        #expect(notYet.title == "No findings yet")
        #expect(notYet.text(appName: "Parcel Pal") == "Findings need a full 28 days to compare. Parcel Pal has 9; the first ones come around \(AnalyticsText.day(nov29)).")
        #expect(FindingsListState.tooQuiet.text(appName: "Quiet Timer")?.hasPrefix("Quiet Timer has too few page views") == true)
        #expect(FindingsListState.nothingStandsOut.text(appName: "Tempo") == "Nothing stands out: every step is near Tempo’s average.")
        #expect(FindingsListState.list.text(appName: "Lumen") == nil)
    }

    @Test func lumenListsItsFindingsAndANewAppHasNoneYet() {
        #expect(model().findingsListState == .list)
        guard case .notYet = model(AppIDs.parcel).findingsListState else {
            Issue.record("Parcel Pal has 9 days")
            return
        }
    }

    @Test func aFindingWaitingInReviewAndPushSaysSo() {
        #expect(FindingsText.waiting(count: 0, area: .pricing) == nil)
        #expect(FindingsText.waiting(count: 1, area: .pricing) == "1 change in \(AnalyticsArea.pricing.title) is waiting in Review & Push.")
        #expect(FindingsText.waiting(count: 3, area: .storePage) == "3 changes in \(AnalyticsArea.storePage.title) are waiting in Review & Push.")
        #expect(FindingsText.heading(count: 1, days: 28) == "1 finding from the last 28 days")
        #expect(FindingsText.heading(count: 5, days: 28) == "5 findings from the last 28 days")
    }

    @Test func newActedOnAndDismissedFindingsAreCountedApart() throws {
        let store = DebugAnalyticsData.store()
        let model = model(store: store)
        let open = model.findingsCount(.open)
        #expect(open > 0)
        let germany = try #require(model.openFindings.first { $0.id == "territory.downloads.DE" })
        #expect(model.findings.isNew(germany), "New until What to Try is read")
        model.tab = .whatToTry
        #expect(!model.findings.isNew(germany))

        model.dismiss(germany)
        #expect(model.findingsCount(.dismissed) == 1)
        #expect(model.findingsCount(.open) == open - 1)
        model.restore(germany.id)
        #expect(model.findingsCount(.dismissed) == 0)

        // Followed on Sep 30, before the subtitle's push on Oct 2: acted on, with its result.
        store.updateFindings({ $0.actedOn["territory.downloads.DE"] = DebugAnalyticsData.date(month: 9, day: 30) }, for: AppIDs.lumen)
        model.recompute()
        #expect(model.findingsCount(.actedOn) >= 1)
        #expect(model.actedFindings.contains { $0.id == "territory.downloads.DE" })
    }
}
#endif
