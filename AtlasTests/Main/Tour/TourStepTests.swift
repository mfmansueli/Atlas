//
//  TourStepTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("TourStep")
struct TourStepTests {
    @Test func fiveTipsCountedOneOfFive() {
        #expect(TourStep.allCases.map(\.countText) == ["1 of 5", "2 of 5", "3 of 5", "4 of 5", "5 of 5"])
    }

    @Test func everyTipButTheLastHasNextAndSkip() {
        for step in TourStep.allCases.dropLast() {
            #expect(step.nextTitle == "Next")
            #expect(step.alternativeTitle == "Skip the Tour")
            #expect(!step.isLast)
        }
    }

    @Test func theLastTipEndsOrConnectsAnAssistant() {
        #expect(TourStep.settings.isLast)
        #expect(TourStep.settings.next == nil)
        #expect(TourStep.settings.nextTitle == "Done")
        #expect(TourStep.settings.alternativeTitle == "Connect an Assistant…")
    }

    @Test func theTipsSayTheDesignsWords() {
        #expect(TourStep.apps.title == "Your apps are here")
        #expect(TourStep.sections.title == "Each section is a part of your App Store page")
        #expect(TourStep.autopilot.title == "Let your assistant do the work")
        #expect(TourStep.reviewPush.title == "Nothing changes until you push")
        #expect(TourStep.settings.title == "Settings are always here")
        #expect(TourStep.settings.text.contains("⌘,"))
        #expect(TourStep.autopilot.text.hasSuffix("You can always do the same by hand."))
    }

    @Test func eachTipHasItsOwnGlyph() {
        #expect(Set(TourStep.allCases.map(\.systemImage)).count == TourStep.allCases.count)
    }

    #if DEBUG
    @Test func eachTipHasItsScene() {
        #expect(TourStep.allCases.map(TourDebugScenes.id(for:)) == TourDebugScenes.ids)
    }

    @MainActor
    @Test func unknownIDsAreLeftToOtherAreas() {
        #expect(TourDebugScenes.view(for: "nav-apps") == nil)
    }
    #endif
}
