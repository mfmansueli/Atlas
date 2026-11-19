//
//  MenuBarGlyphTests.swift
//  AtlasTests
//

import AppKit
import Testing
@testable import Atlas

@MainActor
@Suite("MenuBarGlyph and GlobeBand")
struct MenuBarGlyphTests {
    @Test func theWorkingLoopIsEightFramesIn2_6Seconds() {
        #expect(MenuBarGlyph.frameCount == 8)
        #expect(abs(MenuBarGlyph.frameInterval - 0.325) < 1e-9)
    }

    @Test func frontStretchMovesTwelveAndAHalfPerFrameAsTheSVG() {
        #expect(MenuBarGlyph.frontOffset(frame: 0) == 18)
        #expect(MenuBarGlyph.frontOffset(frame: 1) == 5.5)
        #expect(MenuBarGlyph.frontOffset(frame: 7) == -69.5)
        // Wraps round.
        #expect(MenuBarGlyph.frontOffset(frame: 8) == 18)
        #expect(MenuBarGlyph.frontOffset(frame: -1) == -69.5)
    }

    @Test func imagesAreTemplatesAtMenuBarSize() {
        for state in [MenuBarIconState.idle, .working, .needsYou, .paused, .cantConnect] {
            let image = MenuBarGlyph.image(for: state)
            #expect(image.isTemplate)
            #expect(image.size == NSSize(width: 18, height: 18))
            #expect(image.accessibilityDescription == state.accessibilityLabel)
        }
        #expect(MenuBarGlyph.image(for: .working, frame: 3).cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)
    }

    @Test func halvesRunEndToEnd() {
        let band = GlobeBand(rx: 470, ry: 150, rotation: 0)
        // Front: left end, bottom (y down), right end.
        #expect(abs(band.theta(on: .front, atLength: 0) - .pi) < 1e-9)
        #expect(abs(band.theta(on: .front, atLength: 1)) < 1e-9)
        let middle = band.point(theta: band.theta(on: .front, atLength: 0.5))
        #expect(abs(middle.x) < 1)
        #expect(abs(middle.y - 150) < 1)
        // Back: right end, top, left end.
        let top = band.point(theta: band.theta(on: .back, atLength: 0.5))
        #expect(abs(top.y + 150) < 1)
    }

    @Test func equalLengthsAreEqualArcsNotEqualAngles() {
        let band = GlobeBand(rx: 470, ry: 150, rotation: 0)
        // A tenth of the way along is much less than a tenth of the angle
        // near the narrow end of a flat ellipse.
        let theta = band.theta(on: .front, atLength: 0.1)
        #expect(Double.pi - theta > 0.1 * .pi)
    }

    @Test func pathsAreTurnedByTheRotation() {
        let band = GlobeBand.menuBar
        let box = band.path(.front).boundingBoxOfPath
        // Turned −24°, the right end sits higher (smaller y) than the left.
        let right = band.turned(band.point(theta: 0))
        let left = band.turned(band.point(theta: .pi))
        #expect(right.y < left.y)
        #expect(box.minX < -400)
        #expect(box.maxX > 400)
    }
}
