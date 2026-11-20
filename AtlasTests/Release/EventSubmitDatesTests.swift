//
//  EventSubmitDatesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Submit sheet and a ticked In-App Event's dates, at the view
/// model's clock (Nov 16, 12:00 GMT). Alba 1.2.0: App Store Connect
/// refused "7 Days of Gratitude" because its card was set to show from a
/// time that had passed ("Supplied date must be in the future"). Now such
/// an event blocks Submit with Fix…, a sheet left open catches a date that
/// passes, App Review's time only warns, and a refusal names the date.
@MainActor
@Suite("Release · In-App Event dates")
struct EventSubmitDatesTests {
    typealias Data = DebugReleaseData
    typealias Events = DebugInAppEventsData

    private let release = FakeReleaseServices()
    private let queue = ChangeQueue()
    private let store = DebugReleaseData.store(.prepare)
    private let app = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen } ?? DebugFixtures.apps[0]
    private let events = InAppEventsStore()
    private let claims = ProjectLinkClaimsCenter()
    private static let gmt = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))

    /// The Mood Calendar, its card from `publish` (hours from now).
    private static func mood(publish hours: Double) -> InAppEvent {
        var mood = Events.mood
        mood.schedules[0].publishStart = Data.today.addingTimeInterval(hours * 3600)
        return mood
    }

    /// Lumen 1.4 with everything else ready, the Mood Calendar ticked and
    /// lumen:// claimed by the project.
    private func makeModel(mood: InAppEvent) async -> ReleaseViewModel {
        var services = ReleaseDebugScenes.services(.prepare, encryption: .exempt)
        services.inAppEvents = DebugInAppEventsServices(events: [Events.winter, mood, Events.gratitude])
        var storePage = DebugStorePageServices()
        storePage.whatsNew = Data.whatsNew.merging([Data.missingLocale: Data.suggestedWhatsNew]) { _, new in new }
        services.storePage = storePage
        release.status = Data.status(.prepare)
        services.release = release
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let model = ReleaseViewModel(app: app, services: services, store: store, queue: queue, suggestions: FieldSuggestionStore(), push: push)
        model.now = { Data.today }
        model.eventsStore = events
        model.linkClaims = claims
        await model.load()
        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"])), for: app.id)
        return model
    }

    @Test func aTickedEventWhoseCardDateHasPassedBlocksSubmit() async throws {
        let mood = Self.mood(publish: -12)
        let model = await makeModel(mood: mood)
        #expect(model.tickedEvents.map(\.id) == [Events.moodID])
        let preflight = model.preflight(of: mood, format: Self.gmt)
        #expect(preflight.blocks)
        #expect(preflight.missing.map(\.id) == ["publishStartPassed"])
        let item = try #require(preflight.missing.first)
        #expect(item.text == """
        The card was set to show from \(Self.gmt.date(mood.schedules[0].publishStart ?? .now)), which has passed. App Store Connect only \
        takes dates in the future.
        """)
        // Fix… opens the event's page on "Shows from".
        #expect(item.need?.dateField == .publishStart)
        #expect(model.blockers == ["fix or untick “Mood Calendar”"])
        #expect(!model.canSubmit)
        #expect(await model.submit() == false)
        #expect(release.plans.isEmpty)
        // Without it, the version goes.
        model.setEvent(Events.moodID, goesWithVersion: false)
        #expect(model.canSubmit)
    }

    @Test func aSheetLeftOpenCatchesADateThatPasses() async {
        let mood = Self.mood(publish: 0.5)
        let model = await makeModel(mood: mood)
        #expect(!model.preflight(of: mood).blocks)
        // Within App Review's 2 days: a warning, Submit still on.
        #expect(model.preflight(of: mood).reviewTime.map(\.id) == ["cardShowsSoon"])
        #expect(model.canSubmit)

        model.now = { Data.today.addingTimeInterval(3600) }
        #expect(model.preflight(of: mood).missing.map(\.id) == ["publishStartPassed"])
        #expect(!model.canSubmit)
        #expect(await model.submit() == false)
        #expect(release.plans.isEmpty)
    }

    @Test func newDatesWaitingCountOncePushedFirst() async throws {
        let mood = Self.mood(publish: -12)
        let model = await makeModel(mood: mood)
        var dates = try #require(mood.dates)
        dates.publishStart = Data.today.addingTimeInterval(48 * 3600)
        try queue.upsert(#require(InAppEventChangeBuilder(appID: app.id).datesChange(to: dates, of: mood, now: Data.today, source: .you)))
        model.options.pushesChanges = true
        #expect(!model.preflight(of: mood).blocks)
        #expect(model.preflight(of: mood).reviewTime.isEmpty)
        model.options.pushesChanges = false
        #expect(model.preflight(of: mood).missing.map(\.id) == ["publishStartPassed"])
    }

    @Test func anEventStartingSoonWarnsAndKeepsSubmitOn() async {
        let model = await makeModel(mood: InAppEventsDatesDebugScenes.soonMood)
        let preflight = model.preflight(of: InAppEventsDatesDebugScenes.soonMood)
        #expect(!preflight.blocks)
        #expect(preflight.reviewTime.map(\.id) == ["eventStartsSoon"])
        #expect(preflight.reviewTime.first?.text.hasPrefix("The event starts in 20 hours.") == true)
        #expect(model.canSubmit)
    }

    // MARK: - When App Store Connect refuses

    private static let plan = SubmissionPlan(
        appID: "lumen", versionID: "v14", platform: "IOS", buildID: "b212", attachedBuildID: "b212", usesNonExemptEncryption: nil,
        timing: .manual, isPhased: false, eventIDs: [Events.moodID]
    )

    @Test func aDateThatHasPassedIsNamedInTheRefusal() {
        let mood = Self.mood(publish: -12)
        let events = [Events.winter, mood, Events.gratitude]
        let line = """
        “Mood Calendar”: the card was set to show from \(Self.gmt.date(mood.schedules[0].publishStart ?? .now)), which has passed. App Store \
        Connect only takes dates in the future. Change “Shows from” on the event’s page (Fix…), then Submit again.
        """
        let send = SubmissionFailure(
            step: .send, message: "This resource cannot be reviewed. • Supplied date must be in the future (In-App Event \(Events.moodID))",
            submissionID: "sub1", hasVersion: true, eventIDs: [Events.moodID], underlying: nil
        )
        let text = ReleaseViewModel.failureText(send, events: events, plan: Self.plan, versionString: "1.4", now: Data.today, format: Self.gmt)
        #expect(text.contains(line))
        // The reason names the event, as App Store Connect sent it.
        #expect(text.contains("Supplied date must be in the future (“Mood Calendar”)"))

        let add = SubmissionFailure(
            step: .addEvent(Events.moodID), message: "Supplied date must be in the future", submissionID: "sub1", hasVersion: true, eventIDs: [],
            underlying: nil
        )
        let lines = ReleaseViewModel.pastDateLines(add, events: events, plan: Self.plan, now: Data.today, format: Self.gmt)
        #expect(lines == [line])

        // Another reason, or no date that has passed: nothing to add.
        let other = SubmissionFailure(step: .send, message: "Something else", submissionID: nil, hasVersion: false, eventIDs: [], underlying: nil)
        #expect(ReleaseViewModel.pastDateLines(other, events: events, plan: Self.plan, now: Data.today).isEmpty)
        #expect(ReleaseViewModel.pastDateLines(send, events: [Events.winter, Events.mood], plan: Self.plan, now: Data.today).isEmpty)
    }
}
#endif
