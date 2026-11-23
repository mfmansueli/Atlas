//
//  NewInAppEventTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new In-App Event's checks, the same for the New Event sheet and
/// `propose_in_app_event`: Apple's limits on the reference name, the dates,
/// the deep link and the texts, a start in the future, and a reference name
/// no other event has. "Now" is Nov 16, 2026.
@MainActor
@Suite("NewInAppEvent · checks")
struct NewInAppEventTests {
    typealias Data = InAppEventsTestData

    /// A week-long event from Nov 30, shown from Nov 23, with English texts.
    private func makeEvent() -> NewInAppEvent {
        var event = NewInAppEvent(now: Data.now)
        event.referenceName = "Spring Reset 2027"
        event.texts["en-US"] = [.name: "Spring Reset", .shortDescription: "A fresh start", .longDescription: "Seven days of small habits."]
        return event
    }

    @Test func aWellFormedEventHasNoProblem() {
        #expect(makeEvent().problem == nil)
        #expect(makeEvent().problems(now: Data.now, takenReferenceNames: ["Winter Reflection 2026"]).isEmpty)
    }

    @Test func eachTextIsCheckedAgainstApplesLimit() {
        var event = makeEvent()
        event.texts["en-US"]?[.name] = String(repeating: "a", count: 31)
        event.texts["de-DE"] = [.shortDescription: String(repeating: "b", count: 51), .longDescription: String(repeating: "c", count: 121)]
        #expect(event.problems() == [
            "de-DE · Short Description is 51 characters; the limit is 50.",
            "de-DE · Long Description is 121 characters; the limit is 120.",
            "en-US · Event Name is 31 characters; the limit is 30.",
        ])
        event.texts["de-DE"] = [.longDescription: String(repeating: "c", count: 120)]
        event.texts["en-US"]?[.name] = String(repeating: "a", count: 30)
        #expect(event.problem == nil)
    }

    @Test func anEventLastsFrom15MinutesTo31Days() {
        var event = makeEvent()
        event.eventEnd = event.eventStart.addingTimeInterval(31 * 86400)
        #expect(event.problem == nil)
        event.eventEnd = event.eventStart.addingTimeInterval(31 * 86400 + 60)
        #expect(event.problem == "An event can last 31 days at most. End it sooner or start it later.")
        event.eventEnd = event.eventStart.addingTimeInterval(14 * 60)
        #expect(event.problem == "An event has to last at least 15 minutes.")
        event.eventEnd = event.eventStart
        #expect(event.problem == "The event has to end after it starts.")
    }

    @Test func theCardShowsAtMost14DaysBeforeTheEvent() {
        var event = makeEvent()
        event.publishStart = event.eventStart.addingTimeInterval(-14 * 86400)
        #expect(event.problem == nil)
        event.publishStart = event.eventStart.addingTimeInterval(-14 * 86400 - 60)
        #expect(event.problem == "The card can show at most 14 days before the event starts. Show it from later.")
        event.publishStart = event.eventStart.addingTimeInterval(60)
        #expect(event.problem == "The card can’t start showing after the event has started.")
    }

    @Test func theEventStartsInTheFuture() {
        var event = makeEvent()
        #expect(event.problems(now: event.publishStart.addingTimeInterval(-1)).isEmpty)
        // Its card's date has passed: App Store Connect refuses that too
        // ("Supplied date must be in the future", Alba 1.2.0).
        #expect(event.problems(now: event.eventStart.addingTimeInterval(-1)) == ["The card has to start showing in the future. Show it from later."])
        #expect(event.problems(now: event.eventStart) == ["The event has to start in the future. Move its dates later."])
        // Without a clock, only what the event says itself.
        event.eventStart = Data.day(-3)
        event.eventEnd = Data.day(-1)
        event.publishStart = Data.day(-5)
        #expect(event.problem == nil)
        #expect(event.problems(now: Data.now).count == 1)
    }

    @Test(arguments: ["https://alba.app/challenge/2027", "alba://challenge", "alba://", "com.example.alba://open?event=new-year"])
    func aDeepLinkIsAUniversalLinkOrTheAppsScheme(_ link: String) {
        var event = makeEvent()
        event.deepLink = link
        #expect(event.problem == nil)
    }

    @Test(arguments: ["not a link", "https://", "alba:", "challenge/2027", "https://alba.app/new year", "1alba://open"])
    func anythingElseIsRefused(_ link: String) {
        var event = makeEvent()
        event.deepLink = link
        #expect(event.problem?.hasPrefix("The deep link isn’t a valid URL.") == true)
    }

    @Test func noTwoEventsShareAReferenceName() {
        let event = makeEvent()
        let problems = event.problems(takenReferenceNames: ["  spring reset 2027 "])
        #expect(problems.count == 1)
        #expect(problems.first?.hasPrefix("“Spring Reset 2027” is taken by another event") == true)
        var long = event
        long.referenceName = String(repeating: "r", count: 65)
        #expect(long.problem == "Shorten the reference name to 64 characters.")
    }
}
