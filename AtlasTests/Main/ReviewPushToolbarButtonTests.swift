//
//  ReviewPushToolbarButtonTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The toolbar's Review & Push: its arrow bounces once when something
/// accepted joins it (board 57), not while a push counts down.
@Suite("ReviewPushToolbarButton")
struct ReviewPushToolbarButtonTests {
    @Test func moreWaitingBounces() {
        #expect(ReviewPushToolbarButton.bounces(from: 0, to: 1, isSending: false))
        #expect(ReviewPushToolbarButton.bounces(from: 3, to: 7, isSending: false))
    }

    @Test func fewerOrAPushDoesnt() {
        #expect(!ReviewPushToolbarButton.bounces(from: 7, to: 3, isSending: false), "Undo or a push took some")
        #expect(!ReviewPushToolbarButton.bounces(from: 3, to: 3, isSending: false))
        #expect(!ReviewPushToolbarButton.bounces(from: 3, to: 4, isSending: true), "While a push runs the arrow keeps rising anyway")
    }
}
