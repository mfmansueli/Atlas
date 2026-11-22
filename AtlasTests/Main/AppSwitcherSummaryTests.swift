//
//  AppSwitcherSummaryTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("AppSwitcherSummary")
struct AppSwitcherSummaryTests {
    @Test func noOtherAppHasNoLine() {
        let summary = AppSwitcherSummary(others: [])
        #expect(!summary.hasOthers)
        #expect(summary.line.isEmpty)
        #expect(summary.accessibilityLabel(appName: "Lumen Journal") == "App: Lumen Journal. Switch app")
    }

    @Test func otherAppsWithoutSuggestionsAreJustCounted() {
        #expect(AppSwitcherSummary(others: [("Habitat", 0)]).line == "1 other app")
        let five = AppSwitcherSummary(others: [("A", 0), ("B", 0), ("C", 0), ("D", 0), ("E", 0)])
        #expect(five.line == "5 other apps")
        #expect(five.suggestionsText.isEmpty)
    }

    @Test func severalAppsWithSuggestionsAreCountedInPurple() {
        let summary = AppSwitcherSummary(others: [("Habitat", 3), ("Tempo", 0), ("Quiet", 7), ("D", 0), ("E", 0)])
        #expect(summary.othersText == "5 other apps")
        #expect(summary.suggestionsText == " · 2 with suggestions")
        #expect(summary.line == "5 other apps · 2 with suggestions")
    }

    @Test func oneAppWithSuggestionsIsNamed() {
        #expect(AppSwitcherSummary(others: [("Habitat", 3), ("Tempo", 0)]).suggestionsText == " · 3 suggestions in Habitat")
        #expect(AppSwitcherSummary(others: [("Habitat", 1)]).suggestionsText == " · 1 suggestion in Habitat")
    }

    @Test func aLongNameIsShortenedToItsFirstPart() {
        let summary = AppSwitcherSummary(others: [("Tempo — Metronome & Tuner", 2)])
        #expect(summary.suggestionsText == " · 2 suggestions in Tempo")
    }

    @Test func theAccessibilityLabelReadsTheLine() {
        let summary = AppSwitcherSummary(others: [("Habitat", 3), ("Quiet", 1)])
        #expect(summary.accessibilityLabel(appName: "Lumen Journal") == "App: Lumen Journal. 2 other apps · 2 with suggestions. Switch app")
        #expect(summary.accessibilityLabel(appName: nil) == "Switch app")
    }
}
