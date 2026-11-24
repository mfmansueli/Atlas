//
//  FlowLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// A child wider than a whole line gets the line's width, so a flow row
/// (App Compliance's “Partly on the App Store: …” bar) never holds its page
/// wider than the window.
@Suite("FlowLayout")
struct FlowLayoutTests {
    @Test func aChildThatFitsKeepsItsOwnWidth() {
        #expect(FlowLayout.squeezedWidth(ideal: 200, line: 360) == nil)
        #expect(FlowLayout.squeezedWidth(ideal: 360, line: 360) == nil)
    }

    @Test func aChildWiderThanTheLineGetsTheLine() {
        #expect(FlowLayout.squeezedWidth(ideal: 435, line: 360) == 360)
        #expect(FlowLayout.squeezedWidth(ideal: 435, line: 0) == 0)
    }

    /// With no width offered (an ideal size), every child keeps its own.
    @Test func anIdealSizeSqueezesNothing() {
        #expect(FlowLayout.squeezedWidth(ideal: 2000, line: .infinity) == nil)
    }
}
