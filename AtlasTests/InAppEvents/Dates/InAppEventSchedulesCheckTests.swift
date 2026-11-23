//
//  InAppEventSchedulesCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An event read with more than one schedule, in either order: App Store
/// Connect checks each, so a date that has passed in any of them is a
/// need, named with that schedule's dates, in the "Before App Review"
/// list, the Submit sheet, the settings and a refusal's words. (The
/// `PATCH` writes every schedule: `InAppEventDatesChangeTests`.)
@MainActor
@Suite("In-App Events · every schedule's dates")
struct InAppEventSchedulesCheckTests {
    typealias Data = InAppEventsTestData

    private static let gmt = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))

    /// The new dates: the card from day 8.
    private static let new = InAppEventSchedule(territories: ["USA"], publishStart: Data.day(8), eventStart: Data.day(15), eventEnd: Data.day(45))
    /// The old ones, somewhere else: the card from yesterday.
    private static let old = InAppEventSchedule(territories: ["DEU"], publishStart: Data.day(-1), eventStart: Data.day(15), eventEnd: Data.day(45))

    private static func winter(_ schedules: [InAppEventSchedule]) -> InAppEvent {
        var event = Data.winter
        event.localizations[1].shortDescription = "Kurz"
        event.localizations[1].longDescription = "Lang"
        event.localizations[1].media = Data.media
        event.schedules = schedules
        return event
    }

    /// Either order: the passed one second, then first.
    @Test(arguments: [false, true])
    func aPassedDateInAnyScheduleIsANeed(passedFirst: Bool) throws {
        let event = Self.winter(passedFirst ? [Self.old, Self.new] : [Self.new, Self.old])
        #expect(event.reviewNeeds(now: Data.now) == [.publishStartPassed])
        #expect(!event.canSubmit(now: Data.now))
        #expect(event.brokenDateRules(now: Data.now) == [.publishStartPassed])
        #expect(event.dates(breaking: .publishStartPassed, now: Data.now)?.publishStart == Data.day(-1))

        let items = InAppEventReviewItem.items(
            for: event, changes: [], builder: InAppEventChangeBuilder(appID: Data.app.id), claim: .noDeepLink, appName: Data.app.name,
            now: Data.now, format: Self.gmt
        )
        let item = try #require(items.first { $0.id == "publishStartPassed" })
        #expect(item.state == .missing)
        #expect(item.text.contains(Self.gmt.date(Data.day(-1))), "\(item.text)")
    }

    @Test func everyScheduleAheadIsNoNeed() {
        let event = Self.winter([Self.new, Self.new])
        #expect(event.brokenDateRules(now: Data.now)?.isEmpty == true)
        #expect(event.reviewNeeds(now: Data.now).isEmpty)
    }

    @Test func aScheduleWithoutDatesNeedsThem() {
        var undated = Self.new
        undated.publishStart = nil
        #expect(Self.winter([Self.new, undated]).reviewNeeds(now: Data.now).contains(.dates))
        #expect(Self.winter([]).reviewNeeds(now: Data.now).contains(.dates))
    }

    @Test func theSettingsSayTheDateThatPassed() async throws {
        let event = Self.winter([Self.new, Self.old])
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([event]), store: InAppEventsStore(), queue: ChangeQueue())
        model.now = { Data.now }
        await model.load()
        let publish = try #require(model.settings(of: event, format: Self.gmt).first { $0.key == "publish" })
        #expect(publish.isProblem)
        #expect(publish.value.hasPrefix("Show time "), "\(publish.value)")
        #expect(publish.value.contains(Self.gmt.dayAndTime(Data.day(-1), now: Data.now)))
    }

    @Test func aRefusalNamesTheScheduleWhoseDatePassed() {
        let event = Self.winter([Self.new, Self.old])
        let plan = SubmissionPlan(
            appID: Data.app.id, versionID: "v", platform: "IOS", buildID: "b", attachedBuildID: "b", usesNonExemptEncryption: nil,
            timing: .manual, isPhased: false, eventIDs: [event.id]
        )
        let failure = SubmissionFailure(step: .addEvent(event.id), message: ReleaseViewModel.pastDateReason, submissionID: nil, eventIDs: [])
        let lines = ReleaseViewModel.pastDateLines(failure, events: [event], plan: plan, now: Data.now, format: Self.gmt)
        #expect(lines.count == 1)
        #expect(lines.first?.contains(Self.gmt.date(Data.day(-1))) == true)
    }
}
