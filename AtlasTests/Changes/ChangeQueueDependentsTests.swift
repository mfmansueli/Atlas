//
//  ChangeQueueDependentsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new version's texts depend on it: discarding it (one row, Discard
/// All, Reject All, or queuing another number for its platform)
/// discards them, while App Store Connect taking it leaves them for the
/// rest of the push.
@MainActor
@Suite("Changes that depend on another")
struct ChangeQueueDependentsTests {
    private let builder = NewAppVersionChangeBuilder(appID: "app1")

    private func version(_ number: String, source: ChangeSource = .you) -> PendingChange {
        builder.change(for: NewAppVersion(versionString: number, platform: "IOS"), showsPlatform: false, source: source)
    }

    private func text(_ field: String, of version: PendingChange, source: ChangeSource = .assistant(client: "Claude Code")) -> PendingChange {
        var change = PendingChange(
            id: "storePage.app1.version.{queuedVersion:IOS:2.0}.en-US.\(field)",
            appID: "app1",
            section: .storePage,
            group: version.group,
            title: field,
            oldValue: "",
            newValue: "New",
            source: source,
            requests: [PushRequest(method: .patch, path: "/v1/appStoreVersionLocalizations/{queuedVersion:IOS:2.0:localization:en-US}", body: nil)]
        )
        change.dependsOn = version.id
        return change
    }

    @Test func discardingAVersionDiscardsItsTexts() {
        let version = version("2.0")
        let other = PushFixtures.listing("other", app: "app1")
        let queue = ChangeQueue(changes: [version, text("whatsNew", of: version), text("description", of: version), other])
        queue.discard(id: version.id)
        #expect(queue.changes.map(\.id) == [other.id])
    }

    @Test func aTextAloneGoesAlone() {
        let version = version("2.0")
        let whatsNew = text("whatsNew", of: version)
        let queue = ChangeQueue(changes: [version, whatsNew])
        queue.discard(id: whatsNew.id)
        #expect(queue.changes.map(\.id) == [version.id])
    }

    @Test func aPushedVersionLeavesItsTextsForTheRestOfThePush() {
        let version = version("2.0")
        let whatsNew = text("whatsNew", of: version)
        let queue = ChangeQueue(changes: [version, whatsNew])
        queue.remove(pushed: version.id)
        #expect(queue.changes.map(\.id) == [whatsNew.id])
    }

    @Test func anotherNumberDropsWhatWasWrittenForTheOldOne() {
        let queue = ChangeQueue(changes: [version("2.0"), text("whatsNew", of: version("2.0"))])
        queue.upsert(version("2.0", source: .assistant(client: "Claude Code")))
        #expect(queue.changes.count == 2)
        queue.upsert(version("2.1"))
        #expect(queue.changes.map(\.title) == ["Version 2.1"])
    }

    @Test func discardAllAndRejectAllTakeTheTextsAlong() {
        let assistant = ChangeSource.assistant(client: "Claude Code")
        let version = version("2.0", source: assistant)
        let mine = text("whatsNew", of: version, source: .you)
        let queue = ChangeQueue(changes: [version, mine])
        queue.rejectAll(fromAssistant: "Claude Code")
        #expect(queue.changes.isEmpty)

        let again = ChangeQueue(changes: [version, mine])
        again.discardAll { $0.id == version.id }
        #expect(again.changes.isEmpty)
    }
}
