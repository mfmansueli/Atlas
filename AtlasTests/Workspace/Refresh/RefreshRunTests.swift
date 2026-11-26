//
//  RefreshRunTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A Refresh counts the parts that ended (the app list, the version, the
/// open section) and, once they're in, says how it went.
@Suite("Refresh · the run's parts")
struct RefreshRunTests {
    private let then = Date(timeIntervalSince1970: 1_793_000_000)
    private let now = Date(timeIntervalSince1970: 1_793_000_600)
    private let error = AppleErrorCopy(summary: "Apple didn’t answer. Try again in a minute.", details: "HTTP 503")

    @Test func itWaitsForEveryPart() {
        var run = RefreshRun(lastUpdated: then)
        #expect(run.waiting == Set(RefreshPart.allCases))
        #expect(!run.isDone)
        run.finish(.apps)
        run.finish(.release)
        #expect(run.finished == [.apps, .release])
        #expect(!run.isDone)
        run.finish(.section)
        #expect(run.isDone)
        #expect(run.state(at: now) == .updated(now))
    }

    @Test func aPartEndsOnce() {
        var run = RefreshRun(lastUpdated: nil)
        let first = run.finish(.apps)
        let second = run.finish(.apps)
        #expect(first)
        #expect(!second, "the second report changes nothing")
        #expect(run.finished == [.apps])
    }

    @Test func aFailureKeepsTheLastGoodTime() {
        var run = RefreshRun(lastUpdated: then)
        run.finish(.apps, problem: .failed(error))
        run.finish(.release)
        run.finish(.section)
        #expect(run.state(at: now) == .failed(error, lastUpdated: then))
    }

    @Test func aFailureDoesntWaitForTheSection() {
        // The section shows its own error: the arrow stops once the app
        // list and the version are in.
        var run = RefreshRun(lastUpdated: then)
        run.finish(.apps, problem: .failed(error))
        #expect(!run.isDone)
        run.finish(.release)
        #expect(run.isDone)
    }

    @Test func noNetworkWinsAndKeepsWhereWhatShowsIsFrom() {
        var run = RefreshRun(lastUpdated: then)
        run.finish(.apps, problem: .failed(error))
        run.finish(.release, problem: .offline)
        run.finish(.section, problem: .failed(error))
        #expect(run.problem == .offline)
        #expect(run.state(at: now) == .offline(since: then))
        #expect(RefreshRun(lastUpdated: nil).finishedOffline(at: now) == .offline(since: now))
    }

    @Test func aKeyThatOnlyReadsIsViewOnly() {
        var run = RefreshRun(parts: [.apps], lastUpdated: then)
        run.finish(.apps)
        #expect(run.state(at: now, readOnlyRole: "Developer") == .readOnly(role: "Developer", lastUpdated: now))
        #expect(RefreshRun.readOnlyRole("Developer") == "Developer")
        #expect(RefreshRun.readOnlyRole("Admin") == nil)
        #expect(RefreshRun.readOnlyRole("App Manager") == nil)
        #expect(RefreshRun.readOnlyRole("Team key") == nil, "a role Atlas doesn't know can push")
        #expect(RefreshRun.readOnlyRole(nil) == nil)
    }
}

private extension RefreshRun {
    /// Every part offline.
    func finishedOffline(at now: Date) -> RefreshState {
        var run = self
        for part in RefreshPart.allCases {
            run.finish(part, problem: .offline)
        }
        return run.state(at: now)
    }
}
