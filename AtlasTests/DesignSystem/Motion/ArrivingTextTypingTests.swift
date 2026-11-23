//
//  ArrivingTextTypingTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Effect 3 · Arrived, its text version (word by word with a caret), and
/// Working without units: their timing, as README — Design System §7 sets
/// it (motion v2).
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

    @Test func theCaretFollowsTheWordsAndLeavesAfterTheLast() {
        let total = ArrivingText.duration(wordCount: 5)
        #expect(ArrivingText.caretOpacity(at: 0, total: total) == 0)
        #expect(ArrivingText.caretOpacity(at: 0.1, total: total) == 1)
        #expect(ArrivingText.caretOpacity(at: total, total: total) == 1)
        #expect(abs(ArrivingText.caretOpacity(at: total + ArrivingText.caretFade / 2, total: total) - 0.5) < 1e-9)
        #expect(ArrivingText.caretOpacity(at: total + ArrivingText.caretFade, total: total) == 0)
    }

    /// Working without units (the hello being written): no dots looping,
    /// only the step's name, the same with Reduce Motion.
    @Test func workingWithoutUnitsSaysOnlyTheStep() {
        #expect(AIWorkingStep(text: "Claude Code is writing…").text == "Claude Code is writing…")
        #expect(AIWorkingStep().text == "Writing…")
    }
}
