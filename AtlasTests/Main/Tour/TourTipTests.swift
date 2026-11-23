//
//  TourTipTests.swift
//  AtlasTests
//

import Testing
import TipKit
@testable import Atlas

@MainActor
@Suite("TourTip")
struct TourTipTests {
    /// What the tip's buttons pressed, in order.
    @MainActor
    private final class Presses {
        var list: [String] = []
    }

    private func tip(_ step: TourStep, run: String = "r1") -> TourTip {
        TourTip(step: step, run: run, onNext: {}, onAlternative: {}, onClose: {})
    }

    @Test func eachTipOfARunHasItsOwnID() {
        let ids = Set(TourStep.allCases.map { tip($0).id })
        #expect(ids.count == TourStep.allCases.count)
        #expect(tip(.sections).id == "tour.r1.2")
    }

    @Test func anotherRunHasOtherTips() {
        #expect(tip(.apps, run: "r1").id != tip(.apps, run: "r2").id)
    }

    @Test func theActionsAreNextAndTheAlternative() {
        let ids = tip(.apps).actions.map(\.id)
        #expect(ids == ["next", "alternative"])
        #expect(tip(.settings).actions.count == 2)
    }

    @Test func theActionsRunTheTourButtons() {
        let pressed = Presses()
        let tip = TourTip(step: .apps, run: "r1") {
            pressed.list.append("next")
        } onAlternative: {
            pressed.list.append("alternative")
        } onClose: {
            pressed.list.append("close")
        }
        for action in tip.actions { action.handler() }
        tip.onClose()
        #expect(pressed.list == ["next", "alternative", "close"])
    }
}
