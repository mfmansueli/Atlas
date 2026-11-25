//
//  ReviewShotsMissTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What a card says about a product the run didn't capture.
@Suite("ReviewShotsMiss")
struct ReviewShotsMissTests {
    @Test func aSkippedProductSaysWhy() {
        let miss = ReviewShotsMiss(kind: .skipped, reason: "the paywall shows only Monthly and Lifetime", client: "Claude Code")
        #expect(miss.text == "Claude Code skipped it. The paywall shows only Monthly and Lifetime.")
        #expect(ReviewShotsMiss(kind: .skipped, reason: " ", client: "Claude Code").text == "Claude Code skipped it: the paywall doesn’t show it.")
    }

    @Test func aFailedCheckSaysWhichOne() {
        let miss = ReviewShotsMiss(kind: .checkFailed, reason: "The price didn’t show.", client: "Claude Code")
        #expect(miss.text == "Claude Code tried twice, and a check failed both times: The price didn’t show.")
        #expect(ReviewShotsMiss(kind: .checkFailed, reason: "", client: "Codex").text == "Codex tried twice, and a check failed both times. Nothing was sent.")
    }

    @Test func reasonsBecomeSentences() {
        #expect(ReviewShotsMiss.sentence("  annual isn't shown ") == "Annual isn't shown.")
        #expect(ReviewShotsMiss.sentence("Done?") == "Done?")
        #expect(ReviewShotsMiss.sentence("") == "")
    }
}
