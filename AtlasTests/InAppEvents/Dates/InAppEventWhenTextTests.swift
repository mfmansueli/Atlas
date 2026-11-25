//
//  InAppEventWhenTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The line under an event's name on its details page, said the same way
/// in the event page's preview and in the full-size viewer.
@Suite("InAppEventWhenText")
struct InAppEventWhenTextTests {
    typealias Data = InAppEventsTestData

    @Test func anEventStillToComeSaysWhenItStarts() {
        let start = Data.day(15).formatted(.dateTime.month(.abbreviated).day())
        #expect(InAppEventWhenText.text(for: Data.winter, now: Data.now) == "Starts \(start)")
    }

    @Test func anEventUnderWayIsAvailableNow() {
        #expect(InAppEventWhenText.text(for: Data.update, now: Data.now) == "Now available")
    }

    @Test func anEventPastItsEndHasEnded() {
        #expect(InAppEventWhenText.text(for: Data.gratitude, now: Data.now) == "Ended")
        // Its end passed, whatever state App Store Connect still gives it.
        #expect(InAppEventWhenText.text(for: Data.winter, now: Data.day(46)) == "Ended")
    }

    @Test func aDraftWithoutDatesSaysSo() {
        var event = Data.winter
        event.schedules = []
        #expect(InAppEventWhenText.text(for: event, now: Data.now) == "No dates yet")
    }
}
