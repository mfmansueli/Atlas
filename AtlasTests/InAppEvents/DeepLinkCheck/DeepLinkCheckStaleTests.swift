//
//  DeepLinkCheckStaleTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A `report_deep_link_check` keeps the dates the event was to have; once
/// its start or end moves (queued or in App Store Connect), the check is
/// stale: get_in_app_events says `stale` with why, the event's page says
/// "Checked before the dates changed: Check in the Code", and the Submit
/// sheet notes it without blocking. Alba, Nov 19: the check said "starts
/// 23 Nov", and the event moved to Nov 26.
@MainActor
@Suite("In-App Events · deep link checks after the dates change")
struct DeepLinkCheckStaleTests {
    typealias Data = InAppEventsTestData

    private let store = InAppEventsStore()
    private let changes = ChangeQueue()
    private let claims = ProjectLinkClaimsCenter()
    private let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)
    private static let gmt = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))

    /// Winter, every language written, with its territories: Nov 24 – Dec
    /// 24, its card from Nov 20.
    private static let event: InAppEvent = {
        var event = Data.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(territories: ["USA", "DEU"], publishStart: Data.day(4), eventStart: Data.day(8), eventEnd: Data.day(38))]
        return event
    }()

    private static var dates: InAppEventDates {
        event.dates ?? InAppEventDates(publishStart: .now, eventStart: .now, eventEnd: .now)
    }

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices([Self.event])
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func report() async throws {
        _ = try await call(ReportDeepLinkCheckTool(store: store, now: { Data.now }), [
            "appId": "Lumen Journal", "eventId": "winter", "deepLink": "lumen://challenge/winter", "opens": true,
            "shows": "The Winter challenge", "beforeStart": "The challenge with “Starts Nov 24”", "needsPremium": false,
            "where": "Lumen/LumenApp.swift:48", "build": "1.4 (212)", "testedInSimulator": true, "problems": [],
        ])
    }

    private func check() async throws -> JSONValue {
        let tool = GetInAppEventsTool(store: store, directory: EventArtworkTestFiles.directory(), linkClaims: claims, now: { Data.now })
        let result = try await call(tool, ["appId": "Lumen Journal", "include": ["deepLinkCheck"]]).result
        return try #require(result["events"]?.arrayValue?.first?["deepLinkCheck"])
    }

    private func queue(_ dates: InAppEventDates, source: ChangeSource = .you) throws {
        try changes.upsert(#require(builder.datesChange(to: dates, of: Self.event, now: Data.now, source: source)))
    }

    private func moved(start: Double? = nil, end: Double? = nil, publish: Double? = nil) -> InAppEventDates {
        var dates = Self.dates
        if let start { dates.eventStart = Data.day(start) }
        if let end { dates.eventEnd = Data.day(end) }
        if let publish { dates.publishStart = Data.day(publish) }
        return dates
    }

    // MARK: - The report

    @Test func aCheckKeepsTheDatesItWasMadeUnder() async throws {
        try await report()
        let saved = try #require(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter"))
        #expect(saved.checkedDates == Self.dates)
        let json = try await check()
        #expect(json["stale"] == false)
        #expect(json["checkedDates"]?["eventStart"] == .string(AppStoreConnectDate.text(Self.dates.eventStart)))
        #expect(json["staleReason"] == nil)
    }

    @Test func movedDatesMakeItStaleWithWhy() async throws {
        try await report()
        try queue(moved(start: 10, end: 40))
        let json = try await check()
        #expect(json["stale"] == true)
        let reason = try #require(json["staleReason"]?.stringValue)
        #expect(reason.hasPrefix("Checked when the event was to run \(AppStoreConnectDate.text(Data.day(8)))"))
        #expect(reason.contains("it now runs \(AppStoreConnectDate.text(Data.day(10)))"))
        #expect(reason.hasSuffix("check it again in the code and report it with report_deep_link_check."))
        // Checking again makes it current.
        try await report()
        #expect(try await check()["stale"] == false)
    }

    @Test func theCardsDateAloneChangesNothing() async throws {
        try await report()
        try queue(moved(publish: 5))
        #expect(try await check()["stale"] == false)
    }

    @Test func aCheckOfTheSuggestedDatesIsntStaleWhileTheyWait() async throws {
        let persons = moved(start: 9, end: 39)
        try queue(persons)
        let suggested = moved(start: 10, end: 40)
        let alternative = try #require(builder.datesAlternative(to: suggested, of: Self.event, now: Data.now, source: .assistant(client: "Claude Code")))
        let id = try #require(builder.queuedDates(for: "winter", in: changes.changes)?.id)
        changes.setAlternative(alternative, id: id)
        // Made for the dates this assistant suggested.
        try await report()
        let saved = try #require(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter"))
        #expect(saved.checkedDates == suggested)
        #expect(try await check()["stale"] == false)
        // Dismissed: the person's dates stay, and the check is stale.
        changes.resolveAlternative(id: id, keepAlternative: false)
        #expect(try await check()["stale"] == true)
    }

    @Test func aCheckSavedBeforeAtlasKeptDatesIsNeverStale() {
        let report = InAppEventDeepLinkReport(
            eventID: "winter", deepLink: "lumen://challenge/winter", opens: true, shows: "", beforeStart: "", needsPremium: false,
            location: "", build: "1.4 (212)", testedInSimulator: true, problems: [], client: "Claude Code", date: Data.now
        )
        #expect(!report.isStale(for: moved(start: 10)))
        #expect(report.staleText(for: moved(start: 10), Self.gmt) == nil)
    }

    @Test func theStaleWordsSayWhichDateMoved() {
        var report = InAppEventDeepLinkReport(
            eventID: "winter", deepLink: "lumen://challenge/winter", opens: true, shows: "", beforeStart: "", needsPremium: false,
            location: "", build: "1.4 (212)", testedInSimulator: true, problems: [], client: "Claude Code", date: Data.now, checkedDates: Self.dates
        )
        let start = report.staleText(for: moved(start: 10), Self.gmt)
        #expect(start == """
        Checked when the event was to start \(Self.gmt.date(Data.day(8))); it now starts \(Self.gmt.date(Data.day(10))). \
        What it shows before the start may still name the old dates.
        """)
        let end = report.staleText(for: moved(end: 40), Self.gmt)
        #expect(end?.hasPrefix("Checked when the event was to end \(Self.gmt.date(Data.day(38)))") == true)
        report.checkedDates = nil
        #expect(report.staleText(for: moved(end: 40), Self.gmt) == nil)
    }

    // MARK: - The event's page and the Submit sheet

    @Test func theEventPageSaysItWasCheckedBeforeTheDatesChanged() async throws {
        try await report()
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([Self.event]), store: store, queue: changes)
        model.now = { Data.now }
        model.pageLocales = ["en-US"]
        model.linkClaims = claims
        await model.load()
        model.select("winter")
        #expect(model.deepLinkReportStaleText(of: Self.event, format: Self.gmt) == nil)
        try queue(moved(start: 10, end: 40))
        let text = try #require(model.deepLinkReportStaleText(of: Self.event, format: Self.gmt))
        #expect(text.hasPrefix("Checked when the event was to start"))
    }

    @Test func theSubmitSheetNotesItWithoutBlocking() async throws {
        try await report()
        let saved = try #require(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter"))
        let claimed = ProjectLinkClaimsState.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"]))
        let claim = InAppEventLinkClaim.of("lumen://challenge/winter", in: claimed)
        let preflight = EventSubmitPreflight.check(
            Self.event, items: [], link: (claim, saved), builds: (nil, []), pushesChanges: true, appName: "Lumen Journal",
            dates: moved(start: 10, end: 40), format: Self.gmt
        )
        #expect(!preflight.blocks)
        #expect(preflight.offersCheck)
        #expect(preflight.note?.hasPrefix("Checked before the dates changed. Checked when the event was to start") == true)

        let current = EventSubmitPreflight.check(
            Self.event, items: [], link: (claim, saved), builds: (nil, []), pushesChanges: true, appName: "Lumen Journal",
            dates: Self.dates, format: Self.gmt
        )
        #expect(current.note == nil)
        #expect(!current.offersCheck)
    }
}
