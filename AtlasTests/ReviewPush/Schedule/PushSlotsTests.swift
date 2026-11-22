//
//  PushSlotsTests.swift
//  AtlasTests
//

import Foundation
import Synchronization
import Testing
@testable import Atlas

/// A push's shared steps go one at a time per key, and the many similar
/// requests of a change a few at once, the places shared by every change.
@MainActor
@Suite("Push slots")
struct PushSlotsTests {
    /// Counts the operations going at once.
    private final class Gauge: Sendable {
        private let state = Mutex((now: 0, most: 0, started: 0))

        var most: Int { state.withLock { $0.most } }
        var started: Int { state.withLock { $0.started } }

        func measure(for delay: Duration = .milliseconds(15)) async {
            state.withLock { state in
                state.now += 1
                state.started += 1
                state.most = max(state.most, state.now)
            }
            try? await Task.sleep(for: delay)
            state.withLock { $0.now -= 1 }
        }
    }

    private struct Refusal: Error, Equatable {
        var item: Int
    }

    @Test func oneKeyGoesOneAtATimeAndOthersBesideIt() async {
        let slots = PushSlots()
        let gauge = Gauge()
        let other = Gauge()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<4 {
                group.addTask {
                    await slots.run("group") { await gauge.measure() }
                }
                group.addTask {
                    await slots.run("draft:\(index)") { await other.measure() }
                }
            }
        }
        #expect(gauge.most == 1)
        #expect(gauge.started == 4)
        #expect(other.most > 1)
        #expect(slots.runningCount("group") == 0)
    }

    @Test func aStepThatFailsGivesItsPlaceToTheNext() async {
        let slots = PushSlots()
        do {
            try await slots.run("group") { throw Refusal(item: 1) }
            Issue.record("Expected the refusal")
        } catch {
            #expect(error as? Refusal == Refusal(item: 1))
        }
        let value = await slots.run("group") { 7 }
        #expect(value == 7)
        #expect(slots.runningCount("group") == 0)
    }

    @Test func manyRequestsGoAFewAtOnce() async throws {
        let slots = PushSlots()
        let gauge = Gauge()
        var finished: [Int] = []
        try await slots.forEach(Array(0..<30), key: "prices", width: 4) { item in
            await gauge.measure()
            return item * 2
        } finished: { item, output in
            #expect(output == item * 2)
            finished.append(item)
        }
        #expect(gauge.most == 4)
        #expect(finished.sorted() == Array(0..<30))
        #expect(slots.runningCount("prices") == 0)
    }

    @Test func theDefaultWidthIsThePushs() async throws {
        let slots = PushSlots()
        let gauge = Gauge()
        try await slots.forEach(Array(0..<40), key: "prices") { _ in await gauge.measure() } finished: { _, _ in }
        #expect(gauge.most == PushSchedule.concurrentRequests)
    }

    @Test func afterAFailureNothingElseStartsAndTheErrorIsThrown() async {
        let slots = PushSlots()
        let gauge = Gauge()
        var finished = 0
        do {
            try await slots.forEach(Array(0..<50), key: "prices", width: 2) { item in
                await gauge.measure(for: .milliseconds(5))
                if item == 3 { throw Refusal(item: 3) }
            } finished: { _, _ in
                finished += 1
            }
            Issue.record("Expected the refusal")
        } catch {
            #expect(error as? Refusal == Refusal(item: 3))
        }
        // The one beside it finishes; nothing after starts.
        #expect(gauge.started <= 5)
        #expect(finished == gauge.started - 1)
        #expect(slots.runningCount("prices") == 0)
    }

    /// Two subscriptions' prices share the push's places.
    @Test func changesFanningOutTogetherShareThePlaces() async {
        let slots = PushSlots()
        let gauge = Gauge()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<2 {
                group.addTask {
                    try? await slots.forEach(Array(0..<12), key: "prices", width: 3) { _ in await gauge.measure() } finished: { _, _ in }
                }
            }
        }
        #expect(gauge.most == 3)
        #expect(gauge.started == 24)
    }
}
