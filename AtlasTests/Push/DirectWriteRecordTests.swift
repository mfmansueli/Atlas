//
//  DirectWriteRecordTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Billing Grace Period and Pause Phased Release are writes a button sends
/// itself, after the person confirms: History keeps each (README-An2).
@MainActor
@Suite("History · writes outside Review & Push")
struct DirectWriteRecordTests {
    private let date = DebugAnalyticsData.today

    @Test func theGracePeriodRecordSaysWhatChanged() throws {
        let record = DirectWriteRecord.gracePeriod(appID: "app", appName: "Lumen Journal", duration: .sixteenDays, date: date)
        #expect(record.title == "Billing Grace Period · On, 16 days")
        #expect(record.appName == "Lumen Journal")
        #expect(record.date == date)
        let change = try #require(record.pushed.first)
        #expect(record.changeCount == 1)
        #expect(change.oldValue == "Off")
        #expect(change.newValue == "On, 16 days")
        #expect(change.section == .analytics)
        // Nothing to restore from History, and nothing Analytics measures.
        #expect(record.restoringChanges(at: date).isEmpty)
        #expect(ChangeLog.changes(in: record).isEmpty)
    }

    @Test func thePhasedReleaseRecordSaysPausedOrResumed() {
        let paused = DirectWriteRecord.phasedRelease(appID: "app", appName: "Lumen Journal", version: "1.4", paused: true, date: date)
        #expect(paused.title == "Version 1.4 · Phased release paused")
        #expect(paused.pushed.first?.oldValue == "Rolling out")
        #expect(paused.pushed.first?.newValue == "Paused")
        let resumed = DirectWriteRecord.phasedRelease(appID: "app", appName: "Lumen Journal", version: "1.4", paused: false, date: date)
        #expect(resumed.title == "Version 1.4 · Phased release resumed")
        #expect(resumed.pushed.first?.newValue == "Rolling out")
    }

    @Test func turningOnTheGracePeriodLogsIt() async throws {
        let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.lumen
        let model = AnalyticsViewModel(app: app, store: DebugAnalyticsData.store(), services: DebugAnalyticsServices())
        var records: [PushRecord] = []
        model.onWrite = { records.append($0) }
        try await model.turnOnGracePeriod(.twentyEightDays)
        #expect(records.map(\.title) == ["Billing Grace Period · On, 28 days"])
        #expect(records.first?.appID == app.id)
        #expect(model.gracePeriod?.isOn == true)
    }

    @Test func pausingAndResumingAPhasedReleaseLogsBoth() async {
        let release = FakeReleaseServices()
        release.status = DebugReleaseData.status(.phased)
        var services = ReleaseDebugScenes.services(.phased)
        services.release = release
        let queue = ChangeQueue()
        let history = PushHistory()
        let push = PushController(queue: queue, history: history, transport: FakePushTransport())
        let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]
        let model = ReleaseViewModel(
            app: app, services: services, store: DebugReleaseData.store(.phased), queue: queue, suggestions: FieldSuggestionStore(), push: push
        )
        model.now = { DebugReleaseData.today }
        model.eventsStore = InAppEventsStore()
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()

        await model.perform(.pause)
        #expect(history.records.map(\.title) == ["Version 1.4 · Phased release paused"])
        release.status = DebugReleaseData.status(.paused)
        await model.load()
        await model.perform(.resume)
        #expect(history.records.count == 2)
        #expect(history.records.contains { $0.title == "Version 1.4 · Phased release resumed" })
    }

    @Test func aRefusedPauseIsNotLogged() async {
        let release = FakeReleaseServices()
        release.status = DebugReleaseData.status(.phased)
        release.refuses = true
        var services = ReleaseDebugScenes.services(.phased)
        services.release = release
        let queue = ChangeQueue()
        let history = PushHistory()
        let push = PushController(queue: queue, history: history, transport: FakePushTransport())
        let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]
        let model = ReleaseViewModel(
            app: app, services: services, store: DebugReleaseData.store(.phased), queue: queue, suggestions: FieldSuggestionStore(), push: push
        )
        model.eventsStore = InAppEventsStore()
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        await model.perform(.pause)
        #expect(model.actionError != nil)
        #expect(history.records.isEmpty)
    }
}
#endif
