//
//  ReportFindingActionsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The buttons README-An2 gives the newer reports' findings, and where
/// each one goes: Try an Offer Message…, Write Messages for N Languages…,
/// Make Screenshots for This Page… and See After Changes.
@MainActor
@Suite("Analytics · the newer findings' buttons")
struct ReportFindingActionsTests {
    typealias Rows = ReportsTestData

    private var lumen: [AnalyticsFinding] {
        var dataset = AnalyticsTestData.lumen
        dataset.reports = DebugReportsData.lumen
        dataset.gracePeriod = DebugReportsData.lumenGracePeriod
        return FindingRules.reportFindings(dataset, now: DebugAnalyticsData.today)
    }

    // MARK: - The findings

    @Test func theOfferFindingOffersToTryAnOfferMessage() throws {
        let finding = try #require(lumen.first { $0.id == "retention.offerMessage" })
        #expect(finding.action == .retention)
        #expect(finding.secondAction == .offerMessage)
        #expect(finding.secondAction?.title == "Try an Offer Message…")
    }

    @Test func aPageDeletedMoreOffersItsScreenshots() throws {
        let finding = try #require(lumen.first { $0.id == "page.deletes.Mood tracking" })
        #expect(finding.action == .productPage(name: "Mood tracking"))
        #expect(finding.secondAction == .pageScreenshots(name: "Mood tracking"))
        #expect(finding.secondAction?.title == "Make Screenshots for This Page…")
    }

    /// 400 saw a message and 120 stayed; 200 in DE, AT and FR saw none and 20 stayed.
    private var noMessageArchive: ReportsArchive {
        func row(_ event: String, type: String, territory: String, count: Int, back: Int = 10) -> ReportFact {
            Rows.fact(back, [event, "Pro Monthly", type, type == "No Message" ? "" : "Before you go", "rm-1", "", "", "", "iPhone", territory], [count])
        }
        return Rows.archive([.retention: [
            row("Page views", type: "Text message", territory: "US", count: 400),
            row("Cancels", type: "Text message", territory: "US", count: 280),
            row("Page views", type: "No Message", territory: "DE", count: 100),
            row("Cancels", type: "No Message", territory: "DE", count: 90),
            row("Page views", type: "No Message", territory: "AT", count: 50),
            row("Cancels", type: "No Message", territory: "AT", count: 45),
            row("Page views", type: "No Message", territory: "FR", count: 50),
            row("Cancels", type: "No Message", territory: "FR", count: 45),
            // The newest day, still arriving: only there so the ones above are complete.
            row("Page views", type: "Text message", territory: "US", count: 1, back: 0),
        ]])
    }

    private var pageLanguages: AnalyticsContext {
        AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: ["en-US", "de-DE", "fr-FR"].compactMap(StoreLocaleCatalog.locale(code:))
        )
    }

    @Test func noMessageAsksForMessagesInTheLanguagesWithout() throws {
        var dataset = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        dataset.reports = noMessageArchive
        let findings = FindingRules.reportFindings(dataset, context: pageLanguages, now: .now)
        let finding = try #require(findings.first { $0.id == "retention.noMessage" })
        // DE and AT see the German page, FR the French one.
        #expect(finding.action == .retentionLanguages(count: 2))
        #expect(finding.action.title == "Write Messages for 2 Languages…")
        #expect(finding.area == .retention)
    }

    @Test func withoutThePagesLanguagesItOpensRetention() throws {
        var dataset = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        dataset.reports = noMessageArchive
        let finding = try #require(FindingRules.reportFindings(dataset, now: .now).first { $0.id == "retention.noMessage" })
        #expect(finding.action == .retention)
    }

    @Test func deletionsThatRoseWithAVersionSeeAfterChanges() throws {
        var sessions: [ReportFact] = []
        var crashes: [ReportFact] = []
        var installs: [ReportFact] = []
        for back in 0..<20 {
            sessions.append(Rows.sessions(back, version: "1.3", sessions: 2000, devices: 600))
            sessions.append(Rows.sessions(back, version: "1.4", sessions: 2000, devices: 600))
            crashes.append(Rows.crashes(back, version: "1.3", count: 2))
            crashes.append(Rows.crashes(back, version: "1.4", count: 2))
            installs.append(Rows.fact(back, ["Delete", "", "1.3", "iPhone", "App Store Search", "", "", "Product page", "", "", "US"], [3, 3]))
            installs.append(Rows.fact(back, ["Delete", "", "1.4", "iPhone", "App Store Search", "", "", "Product page", "", "", "US"], [30, 30]))
        }
        var dataset = AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen")
        dataset.reports = Rows.archive([.sessions: sessions, .crashes: crashes, .installs: installs])
        let finding = try #require(FindingRules.reportFindings(dataset, now: .now).first { $0.id == "stability.deletions.1.4" })
        #expect(finding.action == .changes)
        #expect(finding.action.title == "See After Changes")
        #expect(finding.area == .stability)
    }

    // MARK: - The actions

    @Test func eachNewActionHasItsTitleAndArea() {
        #expect(FindingAction.retentionLanguages(count: 1).title == "Write a Message for 1 Language…")
        #expect(FindingAction.offerMessage.area == .retention)
        #expect(FindingAction.retentionLanguages(count: 3).area == .retention)
        #expect(FindingAction.pageScreenshots(name: "Mood tracking").area == .productPages)
        #expect(FindingAction.changes.analyticsTab == .afterChanges)
        #expect(FindingAction.changes.isInsideAnalytics)
        #expect(FindingAction.billing.analyticsTab == .subscriptions)
        #expect(FindingAction.stability.analyticsTab == .stability)
        #expect(FindingAction.offerMessage.analyticsTab == nil)
    }

    @Test func eachActionOpensWhatThePrototypeOpens() {
        let origin = AnalyticsOrigin(appID: "app", text: "A finding", tab: .whatToTry)
        let navigator = WorkspaceNavigator()

        navigator.follow(.offerMessage, origin: origin)
        #expect(navigator.section == .subscriptionPricing)
        #expect(navigator.intent == .newRetentionMessage)

        navigator.follow(.retentionLanguages(count: 2), origin: origin)
        #expect(navigator.section == .subscriptionPricing)
        #expect(navigator.intent == .showRetention)

        navigator.follow(.pageScreenshots(name: "Mood tracking"), origin: origin)
        #expect(navigator.section == .productPages)
        #expect(navigator.intent == .makePageScreenshots(name: "Mood tracking"))
        #expect(navigator.analyticsOrigin == origin)

        navigator.follow(.changes, origin: origin)
        #expect(navigator.section == .analytics)
        #expect(navigator.requestedAnalyticsTab == .afterChanges)
    }
}
#endif
