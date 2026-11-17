//
//  ReleaseStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Atlas remembers of each app's version on its way: the last
/// status seen (to say when it moved), when each step was first seen, and
/// the events ticked to go with the version.
@MainActor
@Suite("ReleaseStore")
struct ReleaseStoreTests {
    private static let now = Date(timeIntervalSince1970: 1_794_830_400)

    private func status(_ state: String, phased: PhasedRelease? = nil, versionID: String = "v14") -> ReleaseStatus {
        var status = ReleaseStatus(version: ReleaseVersion(id: versionID, versionString: "1.4", platform: "IOS", state: state, timing: .manual))
        status.phased = phased
        return status
    }

    private func makeStore() -> ReleaseStore {
        let store = ReleaseStore()
        store.now = { Self.now }
        return store
    }

    @Test func theFirstStatusSeenIsntAMove() {
        let store = makeStore()
        #expect(store.note(status("WAITING_FOR_REVIEW"), for: "1") == nil)
        #expect(store.snapshot(for: "1")?.phase == .waitingForReview)
        #expect(store.snapshot(for: "1")?.versionString == "1.4")
        // Found this way: when it got here isn't known.
        #expect(store.date(of: "waiting", versionID: "v14") == nil)
    }

    @Test func aNewPhaseOfTheSameVersionIsAMoveOnce() {
        let store = makeStore()
        store.note(status("WAITING_FOR_REVIEW"), for: "1")
        store.now = { Self.now.addingTimeInterval(3600) }
        #expect(store.note(status("IN_REVIEW"), for: "1") == .inReview)
        #expect(store.note(status("IN_REVIEW"), for: "1") == nil)
        #expect(store.date(of: "review", versionID: "v14") == Self.now.addingTimeInterval(3600))
        // A later look doesn't move the date.
        store.now = { Self.now.addingTimeInterval(7200) }
        store.note(status("IN_REVIEW"), for: "1")
        #expect(store.date(of: "review", versionID: "v14") == Self.now.addingTimeInterval(3600))
    }

    @Test func aVersionFoundAlreadyLiveHasNoDate() {
        let store = makeStore()
        #expect(store.note(status("READY_FOR_DISTRIBUTION"), for: "1") == nil)
        #expect(store.date(of: "live", versionID: "v14") == nil)
    }

    @Test func anotherVersionStartsOver() {
        let store = makeStore()
        store.note(status("READY_FOR_DISTRIBUTION"), for: "1")
        #expect(store.note(status("PREPARE_FOR_SUBMISSION", versionID: "v15"), for: "1") == nil)
        #expect(store.snapshot(for: "1")?.versionID == "v15")
        #expect(store.date(of: "prepare", versionID: "v15") == nil)
    }

    @Test func aPhasedReleasesDayIsKeptWithoutBeingAMove() {
        let store = makeStore()
        store.note(status("READY_FOR_DISTRIBUTION", phased: PhasedRelease(id: "p", state: .active, day: 2)), for: "1")
        let moved = store.note(status("READY_FOR_DISTRIBUTION", phased: PhasedRelease(id: "p", state: .active, day: 3)), for: "1")
        #expect(moved == nil)
        #expect(store.snapshot(for: "1")?.phase == .phased(day: 3, isPaused: false))
    }

    @Test func onlyVersionsOnTheirWayAreFollowed() {
        let store = makeStore()
        store.note(status("WAITING_FOR_REVIEW"), for: "2")
        store.note(status("PREPARE_FOR_SUBMISSION"), for: "1")
        store.note(status("READY_FOR_DISTRIBUTION", versionID: "v9"), for: "3")
        #expect(store.appsInFlight == ["2"])
    }

    @Test func theEventsTickedForTheVersionAreKept() {
        let store = makeStore()
        #expect(store.eventIDs(for: "1").isEmpty)
        store.setEventIDs(["event-mood"], for: "1")
        #expect(store.eventIDs(for: "1") == ["event-mood"])
        store.setEventIDs([], for: "1")
        #expect(store.archive.eventsWithVersion["1"] == nil)
    }

    @Test func itAllSurvivesARelaunch() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReleaseStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ReleaseStore(directory: directory)
        store.now = { Self.now }
        store.note(status("PENDING_DEVELOPER_RELEASE"), for: "1")
        store.note(status("READY_FOR_DISTRIBUTION", phased: PhasedRelease(id: "p", state: .paused, day: 4)), for: "1")
        store.setEventIDs(["event-mood"], for: "1")

        let reopened = ReleaseStore(directory: directory)
        #expect(reopened.snapshot(for: "1")?.phase == .phased(day: 4, isPaused: true))
        #expect(reopened.date(of: "phased", versionID: "v14") == Self.now)
        #expect(reopened.eventIDs(for: "1") == ["event-mood"])
    }
}
