//
//  PushFlightCenterTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// “Sent to Review & Push” (board 80): what a click sends flies from the
/// click to the pill; typing, the assistant's own proposals and Reduce
/// Motion fly nothing; several accepts fly together, three at most.
@MainActor
@Suite("PushFlightCenter")
struct PushFlightCenterTests {
    private static let pill = CGRect(x: 1000, y: 20, width: 140, height: 44)
    private static let click = CGPoint(x: 520, y: 430)
    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let empty = PushQueueSnapshot()
    private static let oneMore = PushQueueSnapshot(changes: ["wn": "German · What’s New"])

    /// Counts what it's asked to draw.
    private final class Presenter: PushFlightPresenting {
        var presented = 0
        var dismissed = 0
        func present(_: PushFlightCenter) { presented += 1 }
        func dismiss() { dismissed += 1 }
    }

    private func center(presenter: Presenter? = nil, target: CGRect? = pill) -> PushFlightCenter {
        let center = PushFlightCenter(presenter: presenter)
        center.targetFrame = { target }
        return center
    }

    @Test func whatAClickSendsFliesFromTheClickToThePill() throws {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        let flight = try #require(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: false, now: Self.now.addingTimeInterval(0.2)))
        #expect(flight.label == "German · What’s New")
        #expect(flight.start == Self.click)
        #expect(flight.target == CGPoint(x: Self.pill.midX, y: Self.pill.midY))
        #expect(flight.units == 1)
        #expect(center.flights == [flight])
        #expect(center.unitsInAir == 1, "The pill's count waits for it")
        #expect(center.lastClick == nil, "One click, one chip")
    }

    @Test func nothingFliesWithoutAClick() {
        let center = center()
        #expect(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: false, now: Self.now) == nil)
        #expect(center.flights.isEmpty)
    }

    @Test func aChangeLongAfterTheClickDidntComeFromIt() {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        let late = Self.now.addingTimeInterval(PushFlightCenter.clickWindow + 0.1)
        #expect(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: false, now: late) == nil)
    }

    @Test func typingFliesNothing() {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        center.noteTyping()
        #expect(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: false, now: Self.now) == nil)
    }

    @Test func goingDownFliesNothing() {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        #expect(center.queueChanged(from: Self.oneMore, to: Self.empty, reduceMotion: false, now: Self.now) == nil, "Undo")
        #expect(center.lastClick != nil, "The click is still there for what it sends")
    }

    @Test func reduceMotionFliesNothingAndThePillDoesntPulse() {
        let presenter = Presenter()
        let center = center(presenter: presenter)
        center.noteClick(at: Self.click, now: Self.now)
        #expect(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: true, now: Self.now) == nil)
        #expect(center.flights.isEmpty)
        #expect(center.unitsInAir == 0, "The count changes at once")
        #expect(center.landings == 0)
        #expect(presenter.presented == 0)
    }

    @Test func nothingFliesWhileThePillIsntShown() {
        let center = center(target: nil)
        #expect(center.launch(label: "Header", from: Self.click, reduceMotion: false, now: Self.now) == nil)
    }

    @Test func aButtonCanNameItsChip() throws {
        let center = center()
        center.nameNextFlight("Header · German", now: Self.now)
        center.noteClick(at: Self.click, now: Self.now)
        let flight = try #require(center.queueChanged(from: Self.empty, to: Self.oneMore, reduceMotion: false, now: Self.now))
        #expect(flight.label == "Header · German")
    }

    @Test func anAcceptedProposalFliesWithoutAddingToTheCount() throws {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        let old = PushQueueSnapshot(changes: ["p": "Korean · Name"], awaiting: ["p"])
        let new = PushQueueSnapshot(changes: ["p": "Korean · Name"])
        let flight = try #require(center.queueChanged(from: old, to: new, reduceMotion: false, now: Self.now))
        #expect(flight.units == 0)
    }

    @Test func acceptAllFliesOneChipThatCountsThemAll() throws {
        let center = center()
        center.noteClick(at: Self.click, now: Self.now)
        let all = PushQueueSnapshot(changes: ["a": "A", "b": "B", "c": "C"])
        let flight = try #require(center.queueChanged(from: Self.empty, to: all, reduceMotion: false, now: Self.now))
        #expect(flight.label == "3 changes")
        #expect(flight.units == 3)
    }

    @Test func severalAcceptsFlyTogetherAndLandInTurn() throws {
        let presenter = Presenter()
        let center = center(presenter: presenter)
        let first = try #require(center.launch(label: "One", from: Self.click, reduceMotion: false, now: Self.now))
        let second = try #require(center.launch(label: "Two", from: Self.click, reduceMotion: false, now: Self.now))
        #expect(center.flights.map(\.label) == ["One", "Two"])
        #expect(center.unitsInAir == 2)
        #expect(presenter.presented == 1, "One overlay for all of them")

        center.land(first.id)
        #expect(center.landings == 1)
        #expect(center.unitsInAir == 1)
        #expect(presenter.dismissed == 0)
        center.land(second.id)
        center.land(second.id)
        #expect(center.landings == 2, "A chip lands once")
        #expect(center.flights.isEmpty)
        #expect(presenter.dismissed == 1)
    }

    @Test func aFourthInTheAirLandsTheOldest() {
        let center = center()
        for label in ["One", "Two", "Three", "Four"] {
            center.launch(label: label, from: Self.click, reduceMotion: false, now: Self.now)
        }
        #expect(center.flights.map(\.label) == ["Two", "Three", "Four"])
        #expect(center.flights.count == PushFlightCenter.maxInAir)
        #expect(center.landings == 1)
    }
}
