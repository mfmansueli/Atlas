//
//  SideColumnLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Atlas

@Suite("SideColumnLayout")
struct SideColumnLayoutTests {
    /// Age Rating's: a 250 pt preview, 20 pt apart, beside at least 420 pt.
    private let layout = SideColumnLayout(sideWidth: 250, minimumMainWidth: 420, spacing: 20)

    @Test func theColumnGoesBesideWhenTheContentKeepsItsMinimum() {
        #expect(layout.placesBeside(in: 690, mainMinimumWidth: 300))
        #expect(layout.placesBeside(in: 1200, mainMinimumWidth: 300))
    }

    @Test func narrowerThanThatItGoesAbove() {
        #expect(!layout.placesBeside(in: 689, mainMinimumWidth: 300))
        #expect(!layout.placesBeside(in: 0, mainMinimumWidth: 300))
    }

    /// Content that can't be as narrow as the minimum (a long translation
    /// on a button) keeps the column above until it fits beside.
    @Test func contentWiderThanTheMinimumNeedsMoreRoom() {
        #expect(!layout.placesBeside(in: 700, mainMinimumWidth: 480))
        #expect(layout.placesBeside(in: 750, mainMinimumWidth: 480))
    }

    @Test func anIdealSizePutsItBeside() {
        #expect(layout.placesBeside(in: nil, mainMinimumWidth: 480))
    }

    @Test func stackedTheColumnGoesAboveByDefault() {
        let tops = layout.stackedTops(mainHeight: 400, sideHeight: 120)
        #expect(tops.side == 0)
        #expect(tops.main == 140)
    }

    /// Overview's: the lists first, the App Store page under them, 16 pt
    /// apart instead of the 24 beside.
    @Test func stackedTheColumnCanGoBelowWithItsOwnSpacing() {
        let below = SideColumnLayout(sideWidth: 300, minimumMainWidth: 380, spacing: 24, stacksSideBelow: true, stackedSpacing: 16)
        let tops = below.stackedTops(mainHeight: 400, sideHeight: 120)
        #expect(tops.main == 0)
        #expect(tops.side == 416)
    }

    /// Overview's lists keep the preview beside them down to a 704 pt page
    /// (380 + 24 + 300); narrower, it goes under them, whatever width the
    /// page had before, so the page never holds the window wider.
    @MainActor
    @Test func overviewStacksUnder704Points() {
        let columns = OverviewPageAndWaiting<EmptyView, EmptyView>.columns
        #expect(columns.stacksSideBelow)
        #expect(columns.placesBeside(in: 704, mainMinimumWidth: 300))
        #expect(!columns.placesBeside(in: 703, mainMinimumWidth: 300))
        #expect(!columns.placesBeside(in: 0, mainMinimumWidth: 300))
    }
}
