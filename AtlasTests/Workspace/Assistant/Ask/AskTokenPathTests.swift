//
//  AskTokenPathTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The token's arc from an asking button to the toolbar (board 56): up
/// quickly, across slowly at first, half size and gone as it lands; then
/// one ring.
@Suite("AskTokenPath")
struct AskTokenPathTests {
    private let path = AskTokenPath(from: CGPoint(x: 937, y: 80), target: CGPoint(x: 1002, y: 26))

    @Test func itStartsOnTheButtonAndLandsOnTheToolbarAtHalfSize() {
        let start = path.state(at: 0)
        #expect(start.center == CGPoint(x: 937, y: 80))
        #expect(start.scale == 1)
        #expect(start.opacity == 1)
        let end = path.state(at: AskTokenPath.duration)
        #expect(abs(end.center.x - 1002) < 0.01)
        #expect(abs(end.center.y - 26) < 0.01)
        #expect(abs(end.scale - 0.5) < 0.001)
        // Almost gone; it goes before the toolbar starts working.
        #expect(end.opacity < 0.2)
    }

    @Test func itRisesBeforeItCrosses() {
        let early = path.state(at: AskTokenPath.duration * 0.3)
        let rise = (80 - early.center.y) / 54
        let across = (early.center.x - 937) / 65
        #expect(rise > 0.7)
        #expect(across < 0.1)
    }

    @Test func itFadesOnlyInTheLastMoment() {
        #expect(path.state(at: AskTokenPath.fadeStart).opacity == 1)
        #expect(abs(path.state(at: AskTokenPath.fadeStart + 0.08).opacity - 0.5) < 0.01)
        #expect(path.state(at: 0.70).opacity < 1e-9)
    }

    @Test func theRingGrowsOutAndIsGoneAfterIt() throws {
        #expect(AskTokenPath.ring(at: -0.1) == nil)
        let first = try #require(AskTokenPath.ring(at: 0))
        #expect(first.spread == 0)
        #expect(abs(first.opacity - 0.6) < 0.001)
        let late = try #require(AskTokenPath.ring(at: 0.8))
        #expect(late.spread > 12)
        #expect(late.opacity < 0.1)
        #expect(AskTokenPath.ring(at: AskTokenPath.ringDuration) == nil)
    }
}
