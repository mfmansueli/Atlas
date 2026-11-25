//
//  PushQueueSnapshotTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What joined Review & Push between two looks at it, and what the chip
/// that flies there says.
@Suite("PushQueueSnapshot")
struct PushQueueSnapshotTests {
    static func change(_ id: String, title: String, new: String = "New", delta: Int? = nil, awaiting: String? = nil) -> PendingChange {
        var change = PendingChange(
            id: id,
            appID: "app",
            section: delta == nil ? .storePage : .subscriptionPricing,
            group: "Group",
            title: title,
            oldValue: "Old",
            newValue: new,
            deltaPercent: delta,
            requests: []
        )
        change.awaitingAcceptance = awaiting
        return change
    }

    @Test func countsChangesScreenshotsAndExtras() {
        let snapshot = PushQueueSnapshot(changes: ["a": "A", "b": "B"], imageCount: 3, extras: ["app/header-de-DE": "Header · German"])
        #expect(snapshot.count == 6)
    }

    @Test func buildsFromTheQueue() {
        let snapshot = PushQueueSnapshot(
            changes: [Self.change("a", title: "German · What’s New"), Self.change("p", title: "Brazil", new: "R$ 9,90", delta: -50, awaiting: "Accept it")],
            imageCount: 0,
            extras: []
        )
        #expect(snapshot.changes == ["a": "German · What’s New", "p": "Brazil · R$ 9,90"])
        #expect(snapshot.awaiting == ["p"])
    }

    @Test func aNewChangeJoins() {
        let old = PushQueueSnapshot(changes: ["a": "A"])
        let new = PushQueueSnapshot(changes: ["a": "A", "b": "German · What’s New"])
        #expect(new.joinedLabels(since: old) == ["German · What’s New"])
        #expect(new.joinedImages(since: old) == 0)
        #expect(old.joinedLabels(since: new).isEmpty, "Going down joins nothing")
    }

    @Test func anAcceptedProposalJoinsThoughTheCountStays() {
        let old = PushQueueSnapshot(changes: ["p": "Korean · Name"], awaiting: ["p"])
        let new = PushQueueSnapshot(changes: ["p": "Korean · Name"])
        #expect(new.joinedLabels(since: old) == ["Korean · Name"])
        #expect(new.count == old.count)
    }

    @Test func screenshotsAndExtrasJoin() {
        let old = PushQueueSnapshot(imageCount: 2)
        let new = PushQueueSnapshot(imageCount: 5, extras: ["app/header-de-DE": "Header · German"])
        #expect(new.joinedImages(since: old) == 3)
        #expect(new.joinedLabels(since: old) == ["Header · German"])
    }

    @Test func theChipNamesOneThingOrCountsSeveral() {
        #expect(PushFlightLabel.make(labels: [], images: 0) == nil)
        #expect(PushFlightLabel.make(labels: ["German · What’s New"], images: 0) == "German · What’s New")
        #expect(PushFlightLabel.make(labels: [], images: 1) == "1 screenshot")
        #expect(PushFlightLabel.make(labels: [], images: 4) == "4 screenshots")
        #expect(PushFlightLabel.make(labels: ["A", "B", "C"], images: 0) == "3 changes", "Accept All")
        #expect(PushFlightLabel.make(labels: ["A"], images: 2) == "3 changes")
    }

    @Test func aPriceIsNamedWithItsNewPrice() {
        #expect(PushFlightLabel.name(of: Self.change("p", title: "Brazil", new: "R$ 9,90", delta: -50)) == "Brazil · R$ 9,90")
        #expect(PushFlightLabel.name(of: Self.change("t", title: "German · Keywords")) == "German · Keywords")
    }
}
