//
//  TrailPathTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// Effect 1 · Trail: the spark from the asking button up to the Autopilot
/// button, then down to the place of the work, 0.7 s per leg; from the
/// toolbar itself only the way down. It fades only as it lands.
@Suite("TrailPath")
struct TrailPathTests {
    private let button = CGPoint(x: 400, y: 300)
    private let autopilot = CGPoint(x: 900, y: 26)
    private let place = CGPoint(x: 420, y: 320)

    @Test func twoLegsOf700msFromAButtonInThePage() {
        let path = TrailPath(from: button, via: autopilot, to: place)
        #expect(path.legs == 2)
        #expect(abs(path.duration - 1.4) < 1e-9)
        #expect(path.state(at: 0).center == button)
        let onToolbar = path.state(at: TrailPath.leg)
        #expect(abs(onToolbar.center.x - autopilot.x) < 0.01)
        #expect(abs(onToolbar.center.y - autopilot.y) < 0.01)
        #expect(onToolbar.opacity == 1)
        let landed = path.state(at: path.duration)
        #expect(abs(landed.center.x - place.x) < 0.01)
        #expect(abs(landed.center.y - place.y) < 0.01)
        #expect(abs(landed.opacity) < 1e-9)
        #expect(abs(TrailPath.toolbarLanding - (TrailPath.delay + 0.7)) < 1e-9)
    }

    @Test func itRisesBeforeItCrossesAndCrossesBeforeItFalls() {
        let path = TrailPath(from: button, via: autopilot, to: place)
        let early = path.state(at: TrailPath.leg * 0.3).center
        let rise = (button.y - early.y) / (button.y - autopilot.y)
        let across = (early.x - button.x) / (autopilot.x - button.x)
        #expect(rise > across)
        let down = path.state(at: TrailPath.leg * 1.3).center
        let back = (autopilot.x - down.x) / (autopilot.x - place.x)
        let fall = (down.y - autopilot.y) / (place.y - autopilot.y)
        #expect(back > fall)
    }

    @Test func fromTheToolbarOnlyTheWayDown() {
        let path = TrailPath(from: autopilot, via: autopilot, to: place)
        #expect(path.legs == 1)
        #expect(path.state(at: 0).center == autopilot)
        let landed = path.state(at: path.duration).center
        #expect(abs(landed.x - place.x) < 0.01)
        #expect(abs(landed.y - place.y) < 0.01)
    }

    @Test func withoutAPlaceItEndsOnTheToolbar() {
        let path = TrailPath(from: button, via: autopilot, to: nil)
        #expect(path.legs == 1)
        let end = path.state(at: path.duration)
        #expect(abs(end.center.x - autopilot.x) < 0.01)
        #expect(abs(end.opacity) < 1e-9)
    }

    @Test func itFadesOnlyInTheLastMoment() {
        let path = TrailPath(from: button, via: autopilot, to: place)
        #expect(abs(path.state(at: path.duration - TrailPath.fade).opacity - 1) < 1e-9)
        #expect(abs(path.state(at: path.duration - TrailPath.fade / 2).opacity - 0.5) < 1e-6)
    }
}
