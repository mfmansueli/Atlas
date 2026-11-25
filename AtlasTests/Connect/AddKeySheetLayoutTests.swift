//
//  AddKeySheetLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// "Add Another Key…" is 920 × 700 (the canvas's Redesign `addkey`
/// sheet), 32 points inside a smaller window, never under 600 × 440; its
/// size then picks what the form hides and how the cards sit.
@Suite("AddKeySheetLayout")
struct AddKeySheetLayoutTests {
    @Test func theDefaultWindowGetsTheDesignSize() {
        let size = AddKeySheetLayout.size(fitting: CGSize(width: 1200, height: 780))
        #expect(size == CGSize(width: 920, height: 700))
    }

    @Test func anUnknownWindowGetsTheDesignSize() {
        #expect(AddKeySheetLayout.size(fitting: nil) == AddKeySheetLayout.preferred)
        #expect(AddKeySheetLayout.size(fitting: .zero) == AddKeySheetLayout.preferred)
    }

    /// The smallest main window (860 × 560 less its 52-point toolbar).
    @Test func theSmallestWindowKeepsTheSheetInside() {
        let window = CGSize(width: 860, height: 508)
        let size = AddKeySheetLayout.size(fitting: window)
        #expect(size == CGSize(width: 828, height: 476))
        #expect(size.width <= window.width)
        #expect(size.height <= window.height)
    }

    /// Settings is 860 × 640.
    @Test func settingsGetsASheetInsideIt() {
        #expect(AddKeySheetLayout.size(fitting: CGSize(width: 860, height: 640)) == CGSize(width: 828, height: 608))
    }

    @Test func neverUnderTheSmallestSize() {
        #expect(AddKeySheetLayout.size(fitting: CGSize(width: 400, height: 300)) == AddKeySheetLayout.smallest)
    }

    /// At the design size everything shows, the cards side by side.
    @Test func theDesignSizeShowsEverything() {
        let layout = WelcomeLayout(windowSize: AddKeySheetLayout.preferred)
        #expect(layout.showsConnectExplanations)
        #expect(layout.showsFieldHints)
        #expect(layout.placesCardsSideBySide)
        #expect(layout.compactHeaderHeight == 150)
    }

    /// In the smallest window only the steps and fields stay, still side by
    /// side, under a shorter header.
    @Test func theSmallestWindowKeepsTheStepsAndFields() {
        let layout = WelcomeLayout(windowSize: AddKeySheetLayout.size(fitting: CGSize(width: 860, height: 508)))
        #expect(!layout.showsConnectExplanations)
        #expect(!layout.showsFieldHints)
        #expect(layout.placesCardsSideBySide)
        #expect(layout.compactHeaderHeight < 150)
    }

    @Test func theCardsStackOnlyInANarrowSheet() {
        #expect(WelcomeLayout(windowSize: CGSize(width: 720, height: 600)).placesCardsSideBySide)
        #expect(!WelcomeLayout(windowSize: CGSize(width: 719, height: 600)).placesCardsSideBySide)
        #expect(!WelcomeLayout(windowSize: AddKeySheetLayout.smallest).placesCardsSideBySide)
    }
}
