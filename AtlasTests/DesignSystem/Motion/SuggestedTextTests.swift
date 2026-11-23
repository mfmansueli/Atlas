//
//  SuggestedTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Effect 3 (Arrived) on a suggestion's text: its words arrive only when the card
/// itself arrives (the same key and date in `ArrivalLedger`), never for a
/// suggestion that was already there or has no date.
@MainActor
@Suite("SuggestedText")
struct SuggestedTextTests {
    @Test func aSuggestionThatJustLandedArrivesWithItsText() {
        let ledger = ArrivalLedger()
        #expect(SuggestedText.isArriving(arrivalKey: "sg_1", arrivedAt: .now, ledger: ledger))
    }

    @Test func oneThatWasAlreadyThereStaysStill() {
        let ledger = ArrivalLedger()
        let earlier = Date.now.addingTimeInterval(-30)
        #expect(!SuggestedText.isArriving(arrivalKey: "sg_1", arrivedAt: earlier, ledger: ledger))
    }

    @Test func oneWithoutADateNeverArrives() {
        let ledger = ArrivalLedger()
        #expect(!SuggestedText.isArriving(arrivalKey: "sg_1", arrivedAt: nil, ledger: ledger))
    }

    /// The card claims its arrival once; drawn again (scrolled back, the
    /// page reopened) neither the card nor its text plays a second time.
    @Test func onceTheCardHasArrivedItsTextDoesntArriveAgain() {
        let ledger = ArrivalLedger()
        let now = Date.now
        #expect(ledger.claim(key: "sg_1", arrivedAt: now) != nil)
        #expect(!SuggestedText.isArriving(arrivalKey: "sg_1", arrivedAt: now, ledger: ledger))
        #expect(SuggestedText.isArriving(arrivalKey: "sg_2", arrivedAt: now, ledger: ledger))
    }
}
