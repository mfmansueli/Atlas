//
//  SubmitAfterPushTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Submit sheet after a push that changed an In-App Event's dates.
/// Alba, Nov 19: the person pushed new dates for "7 Days of Gratitude"
/// (0 failures), yet the sheet still asked them to fix the dates. Now Push
/// and Submit reads the events the push wrote before it checks and names
/// anything; a refusal over a date that had passed goes once the events
/// are read with new dates ahead, and any other stays marked as the last
/// attempt's; a read during Submit keeps the person's choices.
@MainActor
@Suite("Release · Submit after a push")
struct SubmitAfterPushTests {
    typealias Data = DebugReleaseData
    typealias Events = DebugInAppEventsData

    private let release = FakeReleaseServices()
    private let queue = ChangeQueue()
    private let store = DebugReleaseData.store(.prepare)
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]
    private let claims = ProjectLinkClaimsCenter()

    /// The Mood Calendar, its card from `hours` from now.
    private static func mood(publish hours: Double) -> InAppEvent {
        var mood = Events.mood
        mood.schedules[0].publishStart = Data.today.addingTimeInterval(hours * 3600)
        return mood
    }

    /// `event` as App Store Connect has it after a push of `dates`.
    private static func moved(_ event: InAppEvent, to dates: InAppEventDates) -> InAppEvent {
        var event = event
        event.schedules = event.schedules.map { schedule in
            InAppEventSchedule(territories: schedule.territories, publishStart: dates.publishStart, eventStart: dates.eventStart, eventEnd: dates.eventEnd)
        }
        return event
    }

    private static func later(_ event: InAppEvent) throws -> InAppEventDates {
        var dates = try #require(event.dates)
        dates.publishStart = Data.today.addingTimeInterval(48 * 3600)
        return dates
    }

    /// Lumen 1.4 with everything else ready, the Mood Calendar ticked;
    /// `asc` is App Store Connect's events, to change between reads.
    private func makeModel(
        mood: InAppEvent, transport: FakePushTransport = FakePushTransport()
    ) async -> (model: ReleaseViewModel, asc: FakeInAppEventsServices) {
        let asc = FakeInAppEventsServices([Events.winter, mood, Events.gratitude])
        var services = ReleaseDebugScenes.services(.prepare, encryption: .exempt)
        services.inAppEvents = asc
        var storePage = DebugStorePageServices()
        storePage.whatsNew = Data.whatsNew.merging([Data.missingLocale: Data.suggestedWhatsNew]) { _, new in new }
        services.storePage = storePage
        release.status = Data.status(.prepare)
        services.release = release
        let push = PushController(queue: queue, history: PushHistory(), transport: transport, now: { Data.today })
        let model = ReleaseViewModel(app: app, services: services, store: store, queue: queue, suggestions: FieldSuggestionStore(), push: push)
        model.now = { Data.today }
        model.eventsStore = InAppEventsStore()
        model.linkClaims = claims
        await model.load()
        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"])), for: app.id)
        return (model, asc)
    }

    /// App Store Connect's card date for the dates change's conflict check.
    private static func remote(_ event: InAppEvent) throws -> [String: Foundation.Data] {
        let publish = try #require(event.schedules.first?.publishStart)
        let json = #"{"data":{"attributes":{"territorySchedules":[{"publishStart":"\#(AppStoreConnectDate.text(publish))"}]}}}"#
        return ["/v1/appEvents/\(event.id)?fields[appEvents]=territorySchedules": Foundation.Data(json.utf8)]
    }

    private static let somethingElse = SubmissionFailure(step: .send, message: "Something else", submissionID: nil, eventIDs: [])

    @Test func pushAndSubmitChecksTheEventsAsThePushLeftThem() async throws {
        let mood = Self.mood(publish: -12)
        let transport = try FakePushTransport(remote: Self.remote(mood))
        let (model, asc) = await makeModel(mood: mood, transport: transport)
        let dates = try Self.later(mood)
        try queue.upsert(#require(InAppEventChangeBuilder(appID: app.id).datesChange(to: dates, of: mood, now: Data.today, source: .you)))
        model.options.pushesChanges = true
        // The dates waiting count once pushed first.
        #expect(model.canSubmit)

        // App Store Connect has the new dates once the PATCH goes; then it
        // refuses the submission for another reason.
        asc.events = [Events.winter, Self.moved(mood, to: dates), Events.gratitude]
        release.failure = Self.somethingElse
        #expect(await !model.submit())

        #expect(transport.sent.contains { $0.method == .patch && $0.path == "/v1/appEvents/\(Events.moodID)" })
        #expect(queue.changes(for: app.id).isEmpty)
        let read = try #require(model.events.first { $0.id == Events.moodID })
        #expect(read.dates == dates)
        // Nothing asks to fix the dates: the queue is empty and the events
        // read after the push have them ahead.
        #expect(!model.preflight(of: read).blocks)
        #expect(model.eventBlockers.isEmpty)
        #expect(model.submitError?.contains("which has passed") == false)
    }

    /// App Store Connect still answers with the old dates right after the
    /// `PATCH`: the pushed ones stand for two minutes, then one more read.
    @Test func datesJustPushedStandWhileAppStoreConnectCatchesUp() async throws {
        let mood = Self.mood(publish: -12)
        let transport = try FakePushTransport(remote: Self.remote(mood))
        let (model, asc) = await makeModel(mood: mood, transport: transport)
        var waited: TimeInterval = 0
        model.readAgain.pause = { waited = $0 }
        let dates = try Self.later(mood)
        try queue.upsert(#require(InAppEventChangeBuilder(appID: app.id).datesChange(to: dates, of: mood, now: Data.today, source: .you)))
        model.options.pushesChanges = true
        #expect(await model.submit())

        #expect(release.plans.last?.eventIDs.contains(Events.moodID) == true)
        let read = try #require(model.events.first { $0.id == Events.moodID })
        #expect(read.dates == dates)
        #expect(!model.preflight(of: read).blocks)
        #expect(model.submitError == nil)
        // The sheet opened again reads the same: still nothing to fix.
        await model.refreshEvents()
        #expect(model.events.first { $0.id == Events.moodID }?.dates == dates)

        // Two minutes on, App Store Connect has them.
        asc.events = [Events.winter, Self.moved(mood, to: dates), Events.gratitude]
        await model.readAgain.task?.value
        #expect(waited > 115)
        #expect(model.events.first { $0.id == Events.moodID }?.dates == dates)
    }

    @Test func aRefusalOverAPassedDateGoesOnceNewDatesAreRead() async throws {
        // Ahead when Submit ran, an hour ago; passed by now.
        let mood = Self.mood(publish: -0.5)
        let (model, asc) = await makeModel(mood: mood)
        model.now = { Data.today.addingTimeInterval(-3600) }
        release.failure = SubmissionFailure(
            step: .addEvent(Events.moodID), message: ReleaseViewModel.pastDateReason, submissionID: "sub1", hasVersion: true, eventIDs: []
        )
        #expect(await !model.submit())
        let refused = try #require(model.submitError)
        // The read right after the refusal, with the same dates, keeps it.
        #expect(model.submitFailure?.pastDates?.keys.sorted() == [Events.moodID])
        #expect(model.submitFailure?.isFromLastAttempt == false)

        model.now = { Data.today }
        await model.refreshEvents()
        #expect(model.submitError?.hasPrefix("From the last Submit (") == true)
        #expect(model.submitError?.hasSuffix(refused) == true)

        // The person pushed new dates: read again, nothing of it holds.
        asc.events = try [Events.winter, Self.moved(mood, to: Self.later(mood)), Events.gratitude]
        await model.refreshEvents()
        #expect(model.submitError == nil)
        #expect(model.submitFailure == nil)
    }

    @Test func anotherFailureStaysAsTheLastAttempts() async throws {
        let (model, _) = await makeModel(mood: Self.mood(publish: 48))
        release.failure = Self.somethingElse
        #expect(await !model.submit())
        let refused = try #require(model.submitError)
        #expect(!refused.hasPrefix("From the last Submit"))
        await model.refreshEvents()
        let marked = try #require(model.submitError)
        #expect(marked.hasPrefix("From the last Submit ("))
        #expect(marked.hasSuffix(refused))
        // Read again: marked once.
        await model.refreshEvents()
        #expect(model.submitError == marked)
        // A new Submit starts clean.
        release.failure = nil
        #expect(await model.submit())
        #expect(model.submitError == nil)
    }

    @Test func aReadWhileSubmittingKeepsThePersonsChoices() async {
        let (model, _) = await makeModel(mood: Self.mood(publish: 48))
        model.options.buildID = "build-211"
        model.isSubmitting = true
        await model.load()
        #expect(model.options.buildID == "build-211")
        model.isSubmitting = false
        await model.load()
        #expect(model.options.buildID == "build-212")
    }

    @Test func onlyAPassedDateRefusalCanGoByItself() {
        let plan = SubmissionPlan(
            appID: "lumen", versionID: "v14", platform: "IOS", buildID: "b212", attachedBuildID: "b212", usesNonExemptEncryption: nil,
            timing: .manual, isPhased: false, eventIDs: [Events.moodID, Events.winterID]
        )
        let dates = SubmissionFailure(
            step: .send, message: "This resource cannot be reviewed.\n• Supplied date must be in the future (In-App Event \(Events.moodID))",
            submissionID: "sub1", eventIDs: []
        )
        #expect(ReleaseViewModel.onlyPastDateEventIDs(dates, plan: plan) == [Events.moodID])
        let mixed = SubmissionFailure(
            step: .send, message: """
            This resource cannot be reviewed.
            • Supplied date must be in the future (In-App Event \(Events.moodID))
            • You must provide a value for the attribute 'deepLink' with this request (In-App Event \(Events.winterID))
            """, submissionID: "sub1", eventIDs: []
        )
        #expect(ReleaseViewModel.onlyPastDateEventIDs(mixed, plan: plan) == nil)
        #expect(ReleaseViewModel.onlyPastDateEventIDs(Self.somethingElse, plan: plan) == nil)
    }
}
#endif
