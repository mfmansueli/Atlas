//
//  ArrivalLedgerTests.swift
//  AtlasTests
//

import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Effect 3 · Arrived plays only for a suggestion that lands while the
/// person looks, once; what was already there when the page appeared stays
/// still. Arrivals together are a burst: 70 ms apart, at most six move.
@MainActor
@Suite("ArrivalLedger")
struct ArrivalLedgerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aSuggestionShownAsItArrivesPlaysOnce() {
        let ledger = ArrivalLedger()
        let arrived = now.addingTimeInterval(-0.3)

        #expect(ledger.isFresh(key: "sg_1", arrivedAt: arrived, now: now))
        #expect(ledger.claim(key: "sg_1", arrivedAt: arrived, now: now) != nil)
        // Redrawn, scrolled back or shown in a second window: still.
        #expect(!ledger.isFresh(key: "sg_1", arrivedAt: arrived, now: now))
        #expect(ledger.claim(key: "sg_1", arrivedAt: arrived, now: now.addingTimeInterval(0.5)) == nil)
    }

    @Test func aSuggestionAlreadyThereWhenThePageAppearsStaysStill() {
        let ledger = ArrivalLedger()
        // Opened the page, or switched to its section, a while later.
        #expect(ledger.claim(key: "sg_old", arrivedAt: now.addingTimeInterval(-ArrivalLedger.suggestionWindow - 0.1), now: now) == nil)
        #expect(ledger.claim(key: "sg_yesterday", arrivedAt: now.addingTimeInterval(-86400), now: now) == nil)
    }

    @Test func withoutADateNothingArrives() {
        let ledger = ArrivalLedger()
        #expect(ledger.claim(key: "builtin.1.subtitle.x", arrivedAt: nil, now: now) == nil)
    }

    @Test func aClockALittleAheadStillArrivesButNotOneFarAhead() {
        let ledger = ArrivalLedger()
        #expect(ledger.claim(key: "ahead", arrivedAt: now.addingTimeInterval(0.5), now: now) != nil)
        #expect(ledger.claim(key: "farAhead", arrivedAt: now.addingTimeInterval(ArrivalLedger.clockSlack + 1), now: now) == nil)
    }

    @Test func imagesGetALongerWindow() {
        let ledger = ArrivalLedger()
        let made = now.addingTimeInterval(-5)
        #expect(!ledger.isFresh(key: "art", arrivedAt: made, now: now))
        #expect(ledger.claim(key: "art", arrivedAt: made, window: ArrivalLedger.imageWindow, now: now) != nil)
    }

    @Test func eachKeyArrivesOnItsOwn() {
        let ledger = ArrivalLedger()
        let arrived = now.addingTimeInterval(-0.2)
        #expect(ledger.claim(key: "sg_1", arrivedAt: arrived, now: now) != nil)
        #expect(ledger.claim(key: "sg_2", arrivedAt: arrived, now: now) != nil)
    }

    @Test func builtInSuggestionsNeverArriveButAnAssistantsDo() {
        let target = SuggestionTarget(.storePage(locale: "en-US"), field: "subtitle")
        let builtIn = FieldSuggestion.builtIn(appID: "1", target: target, value: "Mood journal", reason: "Repeats the name.")
        #expect(builtIn.arrivedAt == nil)

        let assistant = FieldSuggestion(
            id: "sg_1", appID: "1", target: target, value: "Private diary", reason: "Praised in reviews.",
            source: .assistant(client: "Claude Code"), createdAt: now
        )
        #expect(assistant.arrivedAt == now)
        let provider = FieldSuggestion(id: "sg_2", appID: "1", target: target, value: "Diary", reason: "Shorter.", source: .aiProvider, createdAt: now)
        #expect(provider.arrivedAt == now)
    }

    @Test func arrivalsTogetherTakeTheirPlaceInTheBurst() {
        let ledger = ArrivalLedger()
        let arrived = now.addingTimeInterval(-0.2)
        let places = (0..<8).map { ledger.claim(key: "sg_\($0)", arrivedAt: arrived, now: now.addingTimeInterval(Double($0) * 0.01)) }
        #expect(places == [0, 1, 2, 3, 4, 5, 6, 7])
        // A while later a new burst starts from the first place.
        #expect(ledger.claim(key: "later", arrivedAt: now.addingTimeInterval(1), now: now.addingTimeInterval(1.5)) == 0)
    }

    @Test func aListArrives70msApartAndOnlyItsFirstSixMove() {
        #expect(MotionTiming.staggerDelay(for: 0) == 0)
        #expect(abs((MotionTiming.staggerDelay(for: 1) ?? -1) - 0.07) < 1e-9)
        #expect(abs((MotionTiming.staggerDelay(for: 5) ?? -1) - 0.35) < 1e-9)
        #expect(MotionTiming.staggerDelay(for: 6) == nil)
        #expect(MotionTiming.staggerDelay(for: 40) == nil)
        #expect(MotionTiming.staggerDelay(for: -1) == nil)
    }

    @Test func anArrivalOutOfSightCountsInNewBelowUntilSeen() {
        let offScreen = ArrivalsOffScreen()
        offScreen.add("a")
        offScreen.add("b")
        offScreen.add("b")
        #expect(offScreen.count == 2)
        #expect(NewArrivalsBelowNotice.text(count: 2) == "2 new below")
        offScreen.remove("a")
        #expect(offScreen.count == 1)
        offScreen.removeAll()
        #expect(offScreen.count == 0)
    }

    @Test func anImageDevelopsFromABlurredPaleSmallerPicture() {
        let start = AIArrivedImage.look(developed: 0, reduceMotion: false)
        #expect(start.blur == 9)
        #expect(abs(start.saturation - 0.2) < 1e-9)
        #expect(abs(start.scale - 0.97) < 1e-9)
        #expect(abs(start.opacity - 0.4) < 1e-9)
        let end = AIArrivedImage.look(developed: 1, reduceMotion: false)
        #expect(end == AIArrivedImage.Look(blur: 0, saturation: 1, scale: 1, opacity: 1))
        #expect(AIArrivedImage.duration == 0.8)
        // Reduce Motion only fades.
        #expect(AIArrivedImage.look(developed: 0, reduceMotion: true) == AIArrivedImage.Look(blur: 0, saturation: 1, scale: 1, opacity: 0))
    }
}
