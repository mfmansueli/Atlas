//
//  TimeLeftEstimateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("TimeLeftEstimate")
struct TimeLeftEstimateTests {
    private let start = Date(timeIntervalSinceReferenceDate: 815_000_000)

    @Test func extrapolatesFromHowFarItCame() {
        // A quarter done in 2 minutes: 6 more.
        let seconds = TimeLeftEstimate.seconds(startedAt: start, fraction: 0.25, now: start.addingTimeInterval(120))
        #expect(seconds == 360)
        #expect(TimeLeftEstimate.text(startedAt: start, fraction: 0.25, now: start.addingTimeInterval(120)) == "about 6 min left")
    }

    @Test func saysNothingUntilThereIsEnoughToGoBy() {
        #expect(TimeLeftEstimate.seconds(startedAt: start, fraction: 0.5, now: start.addingTimeInterval(2)) == nil)
        #expect(TimeLeftEstimate.seconds(startedAt: start, fraction: 0.01, now: start.addingTimeInterval(60)) == nil)
        #expect(TimeLeftEstimate.seconds(startedAt: start, fraction: 1, now: start.addingTimeInterval(60)) == nil)
    }

    @Test func roundsToMinutesThenHours() {
        #expect(TimeLeftEstimate.text(seconds: 10) == "about 1 min left")
        #expect(TimeLeftEstimate.text(seconds: 90 * 60) == "about 90 min left")
        #expect(TimeLeftEstimate.text(seconds: 3 * 3600) == "about 3 h left")
    }
}
