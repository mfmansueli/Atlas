//
//  CountTickPolicyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Effect 4 · Count tick: a badge ticks only going up because suggestions
/// came, never going down, on load or when the app changes.
@Suite("CountTickPolicy")
struct CountTickPolicyTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private var settled: Date { start.addingTimeInterval(CountTickPolicy.settleDelay + 1) }

    @Test func goingUpTicks() {
        var policy = CountTickPolicy(count: 2, scope: "app1", now: start)
        #expect(policy.wouldTick(count: 3, scope: "app1", now: settled))
        let ticked1 = policy.update(count: 3, scope: "app1", now: settled)
        #expect(ticked1)
        #expect(policy.count == 3)
        // The first suggestion of a section ticks too.
        var empty = CountTickPolicy(count: 0, scope: "app1", now: start)
        let ticked2 = empty.update(count: 1, scope: "app1", now: settled)
        #expect(ticked2)
    }

    @Test func goingDownOrStayingIsStill() {
        var policy = CountTickPolicy(count: 5, scope: "app1", now: start)
        let ticked3 = policy.update(count: 4, scope: "app1", now: settled)
        #expect(!ticked3)
        let ticked4 = policy.update(count: 0, scope: "app1", now: settled)
        #expect(!ticked4)
        let ticked5 = policy.update(count: 0, scope: "app1", now: settled)
        #expect(!ticked5)
        // Up again from the lower count.
        let ticked6 = policy.update(count: 2, scope: "app1", now: settled)
        #expect(ticked6)
    }

    @Test func countsLoadingAsTheBadgeAppearsAreStill() {
        var policy = CountTickPolicy(count: 0, scope: "app1", now: start)
        let ticked7 = policy.update(count: 12, scope: "app1", now: start.addingTimeInterval(0.4))
        #expect(!ticked7)
        #expect(policy.count == 12)
        let ticked8 = policy.update(count: 13, scope: "app1", now: settled)
        #expect(ticked8)
    }

    @Test func anotherAppIsANewBaseline() {
        var policy = CountTickPolicy(count: 1, scope: "app1", now: start)
        let switched = settled
        let ticked9 = policy.update(count: 9, scope: "app2", now: switched)
        #expect(!ticked9)
        #expect(policy.scope == "app2")
        // Its counts still loading just after the switch: still.
        let ticked10 = policy.update(count: 10, scope: "app2", now: switched.addingTimeInterval(1))
        #expect(!ticked10)
        let ticked11 = policy.update(count: 11, scope: "app2", now: switched.addingTimeInterval(CountTickPolicy.settleDelay + 0.1))
        #expect(ticked11)
    }

    @Test func wouldTickDoesntChangeAnything() {
        let policy = CountTickPolicy(count: 1, scope: nil, now: start)
        #expect(policy.wouldTick(count: 2, scope: nil, now: settled))
        #expect(policy.count == 1)
        #expect(!policy.wouldTick(count: 2, scope: "app1", now: settled))
    }
}
