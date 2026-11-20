//
//  ChangeAlternativeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An assistant's version of a change the person queued waits beside it
/// with its reason and its block: picking it carries both, and the
/// person's stays until they pick.
@MainActor
@Suite("ChangeQueue · alternatives")
struct ChangeAlternativeTests {
    private func change(new: String, source: ChangeSource, note: String? = nil, blocked: String? = nil) -> PendingChange {
        var change = PendingChange(
            id: "dates", appID: "1", section: .inAppEvents, group: "Group", title: "Dates", oldValue: "old", newValue: new, source: source,
            blockedReason: blocked, requests: []
        )
        change.groupNote = note
        return change
    }

    @Test func anAssistantsVersionKeepsItsReasonAndBlock() throws {
        let queue = ChangeQueue()
        queue.upsert(change(new: "mine", source: .you, note: "My note"))
        queue.upsert(change(new: "theirs", source: .assistant(client: "Claude Code"), note: "Start on a Monday.", blocked: "Too long."))
        let kept = try #require(queue.change(id: "dates"))
        #expect(kept.newValue == "mine")
        #expect(kept.source == .you)
        #expect(kept.alternative?.note == "Start on a Monday.")
        #expect(kept.alternative?.blockedReason == "Too long.")
        #expect(kept.blockedReason == nil)
    }

    @Test func pickingTheAssistantsCarriesItsReasonAndBlock() throws {
        let queue = ChangeQueue()
        queue.upsert(change(new: "mine", source: .you, note: "My note"))
        queue.upsert(change(new: "theirs", source: .assistant(client: "Claude Code"), note: "Start on a Monday.", blocked: "Too long."))
        queue.resolveAlternative(id: "dates", keepAlternative: true)
        let picked = try #require(queue.change(id: "dates"))
        #expect(picked.newValue == "theirs")
        #expect(picked.groupNote == "Start on a Monday.")
        #expect(picked.blockedReason == "Too long.")
        #expect(picked.alternative == nil)
    }

    @Test func keepingYoursDropsTheirs() throws {
        let queue = ChangeQueue()
        queue.upsert(change(new: "mine", source: .you, note: "My note"))
        queue.upsert(change(new: "theirs", source: .assistant(client: "Claude Code"), note: "Start on a Monday."))
        queue.resolveAlternative(id: "dates", keepAlternative: false)
        let kept = try #require(queue.change(id: "dates"))
        #expect(kept.newValue == "mine")
        #expect(kept.groupNote == "My note")
        #expect(kept.alternative == nil)
    }

    @Test func setAlternativeAddsAndTakesItBackWithoutTouchingThePersons() {
        let queue = ChangeQueue()
        queue.upsert(change(new: "mine", source: .you))
        let alternative = ChangeAlternative(newValue: "theirs", source: .assistant(client: "Claude Code"), requests: [], note: "Why")
        queue.setAlternative(alternative, id: "dates")
        #expect(queue.change(id: "dates")?.alternative == alternative)
        #expect(queue.change(id: "dates")?.needsDecision == true)
        #expect(queue.change(id: "dates")?.newValue == "mine")
        queue.setAlternative(nil, id: "dates")
        #expect(queue.change(id: "dates")?.alternative == nil)
        #expect(queue.change(id: "dates")?.newValue == "mine")
    }
}
