//
//  WelcomeLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

@Suite("WelcomeLayout and WelcomeStage")
struct WelcomeLayoutTests {
    @Test func theDefaultWindowGivesTheHeaderHalf() {
        let layout = WelcomeLayout(windowSize: CGSize(width: 1200, height: 780))
        #expect(!layout.isShort)
        #expect(abs(layout.largeHeaderHeight - 405.6) < 1e-9)
        #expect(abs(layout.largeMarkSize - 296.4) < 1e-9)
        #expect(layout.compactHeaderHeight == 150)
        #expect(layout.compactMarkSize == 118)
        #expect(layout.showsPointDetails)
    }

    @Test func aShortWindowKeepsOnlyThePointsTitles() {
        let layout = WelcomeLayout(windowSize: CGSize(width: 1000, height: 600))
        #expect(layout.isShort)
        #expect(abs(layout.largeHeaderHeight - 264) < 1e-9)
        #expect(!layout.showsPointDetails)
        #expect(abs(layout.compactHeaderHeight - 132) < 1e-9)
        #expect(abs(layout.compactMarkSize - 102) < 1e-9)
    }

    @Test func theHeaderNeverGoesBelow210() {
        let layout = WelcomeLayout(windowSize: CGSize(width: 900, height: 400))
        #expect(layout.largeHeaderHeight == 210)
    }

    @Test func theMarkIsAtMost300() {
        #expect(WelcomeLayout(windowSize: CGSize(width: 1600, height: 1200)).largeMarkSize == 300)
    }

    @Test func welcomeFirstUnlessTheKeysCouldNotBeRead() {
        #expect(WelcomeStage.initial(hasNotice: false) == .welcome)
        #expect(WelcomeStage.initial(hasNotice: true) == .connect)
    }
}
