//
//  ArrivingTextTypingTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// AI motions 3 (text arriving) and 7 (assistant is typing): their timing,
/// as README — Design System §7 sets it.
@MainActor
@Suite("Motion · text arriving and typing")
struct ArrivingTextTypingTests {
    @Test func wordsKeepTheirSpaces() {
        #expect(ArrivingText.words(in: "Hi! I’m  connected.") == ["Hi! ", "I’m  ", "connected."])
        #expect(ArrivingText.words(in: "").isEmpty)
        #expect(ArrivingText.words(in: "one").count == 1)
    }

    @Test func eachWordTakes280msAnd35msAfterTheLast() {
        #expect(ArrivingText.duration(wordCount: 0) == 0)
        #expect(abs(ArrivingText.duration(wordCount: 1) - 0.28) < 0.0001)
        #expect(abs(ArrivingText.duration(wordCount: 11) - (10 * 0.035 + 0.28)) < 0.0001)
        #expect(ArrivingText.progress(ofWord: 0, at: 0) == 0)
        #expect(ArrivingText.progress(ofWord: 0, at: 0.28) == 1)
        #expect(ArrivingText.progress(ofWord: 2, at: 0.07) == 0)
        let halfway = ArrivingText.progress(ofWord: 1, at: 0.035 + 0.14)
        #expect(halfway > 0.5 && halfway < 1)
    }

    @Test func theDotsRiseInTurn() {
        #expect(TypingIndicator.loop == 1.2)
        #expect(TypingIndicator.lift(phase: 0.2, dot: 0) > 0.99)
        #expect(TypingIndicator.lift(phase: 0.2, dot: 1) == 0)
        #expect(TypingIndicator.lift(phase: 0.4, dot: 1) > 0.99)
        #expect(TypingIndicator.lift(phase: 0.6, dot: 2) > 0.99)
        #expect(TypingIndicator.lift(phase: 0.9, dot: 0) == 0)
    }
}
