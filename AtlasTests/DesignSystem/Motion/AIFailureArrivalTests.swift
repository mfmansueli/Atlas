//
//  AIFailureArrivalTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Effect 5 · Needs you, a failure: a new one slides in 4 pt and stays;
/// the same one, none, or Reduce Motion stays still.
@Suite("AIFailureArrival")
struct AIFailureArrivalTests {
    @Test func onlyANewFailureSlidesIn() {
        #expect(AIFailureArrival.distance == 4)
        #expect(AIFailureArrival.slides(from: nil, to: "paywallNotFound", reduceMotion: false))
        #expect(AIFailureArrival.slides(from: "paywallNotFound", to: "noPrices", reduceMotion: false))
        #expect(!AIFailureArrival.slides(from: "noPrices", to: "noPrices", reduceMotion: false))
        #expect(!AIFailureArrival.slides(from: "noPrices", to: nil, reduceMotion: false))
        #expect(!AIFailureArrival.slides(from: nil, to: "noPrices", reduceMotion: true))
    }
}
