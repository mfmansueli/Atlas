//
//  ArrivalLedgerTests.swift
//  AtlasTests
//

import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Effect 2 · Arrival plays only for a suggestion that lands while the
/// person looks, once; what was already there when the page appeared stays
/// still.
@MainActor
@Suite("ArrivalLedger")
struct ArrivalLedgerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aSuggestionShownAsItArrivesPlaysOnce() {
        let ledger = ArrivalLedger()
        let arrived = now.addingTimeInterval(-0.3)

        #expect(ledger.isFresh(key: "sg_1", arrivedAt: arrived, now: now))
        #expect(ledger.claim(key: "sg_1", arrivedAt: arrived, now: now))
        // Redrawn, scrolled back or shown in a second window: still.
        #expect(!ledger.isFresh(key: "sg_1", arrivedAt: arrived, now: now))
        #expect(!ledger.claim(key: "sg_1", arrivedAt: arrived, now: now.addingTimeInterval(0.5)))
    }

    @Test func aSuggestionAlreadyThereWhenThePageAppearsStaysStill() {
        let ledger = ArrivalLedger()
        // Opened the page, or switched to its section, a while later.
        #expect(!ledger.claim(key: "sg_old", arrivedAt: now.addingTimeInterval(-ArrivalLedger.suggestionWindow - 0.1), now: now))
        #expect(!ledger.claim(key: "sg_yesterday", arrivedAt: now.addingTimeInterval(-86400), now: now))
    }

    @Test func withoutADateNothingArrives() {
        let ledger = ArrivalLedger()
        #expect(!ledger.claim(key: "builtin.1.subtitle.x", arrivedAt: nil, now: now))
    }

    @Test func aClockALittleAheadStillArrivesButNotOneFarAhead() {
        let ledger = ArrivalLedger()
        #expect(ledger.claim(key: "ahead", arrivedAt: now.addingTimeInterval(0.5), now: now))
        #expect(!ledger.claim(key: "farAhead", arrivedAt: now.addingTimeInterval(ArrivalLedger.clockSlack + 1), now: now))
    }

    @Test func imagesGetALongerWindow() {
        let ledger = ArrivalLedger()
        let made = now.addingTimeInterval(-5)
        #expect(!ledger.isFresh(key: "art", arrivedAt: made, now: now))
        #expect(ledger.claim(key: "art", arrivedAt: made, window: ArrivalLedger.imageWindow, now: now))
    }

    @Test func eachKeyArrivesOnItsOwn() {
        let ledger = ArrivalLedger()
        let arrived = now.addingTimeInterval(-0.2)
        #expect(ledger.claim(key: "sg_1", arrivedAt: arrived, now: now))
        #expect(ledger.claim(key: "sg_2", arrivedAt: arrived, now: now))
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

    @Test func theEdgePassGoesOnceRoundAndFadesAtBothEnds() {
        #expect(ArrivalEdgePass<Capsule>.progress(elapsed: 0) == 0)
        #expect(ArrivalEdgePass<Capsule>.progress(elapsed: -1) == 0)
        #expect(ArrivalEdgePass<Capsule>.progress(elapsed: MotionTiming.arrivalPassDuration) == 1)
        #expect(ArrivalEdgePass<Capsule>.progress(elapsed: 5) == 1)
        // Ease-out: well past halfway at half the time.
        #expect(ArrivalEdgePass<Capsule>.progress(elapsed: MotionTiming.arrivalPassDuration / 2) > 0.5)

        #expect(ArrivalEdgePass<Capsule>.angle(progress: 0) == 0)
        #expect(ArrivalEdgePass<Capsule>.angle(progress: 1) == 360)

        #expect(ArrivalEdgePass<Capsule>.opacity(progress: 0) == 0)
        #expect(ArrivalEdgePass<Capsule>.opacity(progress: 0.5) == 1)
        #expect(ArrivalEdgePass<Capsule>.opacity(progress: 1) == 0)
    }
}
