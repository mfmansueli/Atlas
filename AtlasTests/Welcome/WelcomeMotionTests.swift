//
//  WelcomeMotionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("WelcomeMotion")
struct WelcomeMotionTests {
    @Test func sixTilesInTwoGroupsHalfALapApart() {
        let tiles = WelcomeMotion(time: 0).tiles
        #expect(tiles.count == 6)
        // The second group is where the first is, half a lap on: mirrored.
        for index in 0..<3 {
            #expect(abs(tiles[index].x + tiles[index + 3].x) < 1e-6)
            #expect(abs(tiles[index].y + tiles[index + 3].y) < 1e-6)
        }
    }

    @Test func tilesRideTheIconsBand() {
        for time in stride(from: 0.0, to: 16, by: 0.7) {
            for tile in WelcomeMotion(time: time).tiles {
                let onEllipse = pow(tile.x / 440, 2) + pow(tile.y / 130, 2)
                #expect(abs(onEllipse - 1) < 1e-9)
                // In front below the centre, a sliver at the ends.
                #expect(tile.isFront == (tile.y >= 0))
                #expect(abs(tile.widthScale - tile.y / 130) < 1e-9)
            }
        }
    }

    @Test func oneLapIn16SecondsTwiceAsFastWhileReading() {
        let start = WelcomeMotion(time: 0).tiles
        let lap = WelcomeMotion(time: 16).tiles
        let fastLap = WelcomeMotion(time: 8, pace: 2).tiles
        for index in start.indices {
            #expect(abs(start[index].x - lap[index].x) < 1e-6)
            #expect(abs(start[index].x - fastLap[index].x) < 1e-6)
        }
    }

    @Test func meridianSwings9_6SecondsEachWay() {
        #expect(abs(WelcomeMotion(time: 0).meridianScales.0 - 1) < 1e-9)
        #expect(abs(WelcomeMotion(time: 9.6).meridianScales.0 + 1) < 1e-9)
        #expect(abs(WelcomeMotion(time: 4.8).meridianScales.0) < 1e-9)
        // The second ellipse is a quarter swing behind.
        #expect(abs(WelcomeMotion(time: 0).meridianScales.1) < 1e-9)
    }

    @Test func starRestsThenGlintsEveryEightSeconds() {
        // 0.3 of the way into its cycle it's at its brightest.
        let peakTime = 0.3 * 8 - WelcomeMotion.starDelay + 8
        let peak = WelcomeMotion(time: peakTime).star
        #expect(abs(peak.scale - 1.32) < 1e-6)
        #expect(abs(peak.rotation - 16) < 1e-6)
        #expect(abs(peak.haloOpacity - 0.9) < 1e-6)
        let rest = WelcomeMotion(time: 0.8 * 8 - WelcomeMotion.starDelay + 8).star
        #expect(rest.scale == 1)
        #expect(rest.haloOpacity == 0)
        #expect(rest.opacity == 0.86)
        let again = WelcomeMotion(time: peakTime + 8).star
        #expect(abs(again.scale - peak.scale) < 1e-6)
    }

    @Test func orbitLeansBothWaysThenSettles() {
        let start = 17 - WelcomeMotion.orbitDelay
        #expect(WelcomeMotion(time: start).orbit.lean == 0)
        let quarter = WelcomeMotion(time: start + 7.5 / 4).orbit
        let threeQuarters = WelcomeMotion(time: start + 7.5 * 3 / 4).orbit
        #expect(quarter.lean > 0)
        #expect(threeQuarters.lean < 0)
        #expect(abs(quarter.lean) < 3.5)
        #expect(abs(WelcomeMotion(time: start + 3.75).orbit.openness - 1.11) < 1e-9)
        // At rest for the remaining 9.5 s.
        let resting = WelcomeMotion(time: start + 10).orbit
        #expect(resting.lean == 0)
        #expect(resting.openness == 1)
    }

    @Test func orbitKeepsItsOwnPaceWhileReading() {
        #expect(WelcomeMotion(time: 3, pace: 2).orbit == WelcomeMotion(time: 3).orbit)
    }

    @Test func markFloatsElevenPoints() {
        #expect(abs(WelcomeMotion(time: 0).floatOffset + 5) < 1e-9)
        #expect(abs(WelcomeMotion(time: 7).floatOffset - 6) < 1e-9)
        #expect(abs(WelcomeMotion(time: 14).floatOffset + 5) < 1e-9)
    }
}
