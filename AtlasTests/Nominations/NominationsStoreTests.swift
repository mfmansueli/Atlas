//
//  NominationsStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What this Mac keeps of nominations: drafts and edits per app, saved to
/// disk when given a folder; assistants' suggestions replacing their own;
/// and what a read of App Store Connect makes obsolete.
@MainActor
@Suite("Nominations · store")
struct NominationsStoreTests {
    typealias Data = DebugNominationsData

    @Test func draftsAreKeptPerAppAndOnDisk() {
        let folder = FileManager.default.temporaryDirectory.appending(path: "nominations-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = NominationsStore(directory: folder)
        store.save(Data.draft, for: Data.lumen)
        #expect(store.drafts(for: Data.lumen).map(\.id) == [Data.draftID])
        #expect(store.drafts(for: Data.quiet).isEmpty)
        let reopened = NominationsStore(directory: folder)
        #expect(reopened.drafts(for: Data.lumen).map(\.content.name) == ["Lumen 1.4: Weekly reflections"])
        reopened.removeDraft(Data.draftID, for: Data.lumen)
        #expect(NominationsStore(directory: folder).drafts(for: Data.lumen).isEmpty)
    }

    @Test func anAssistantsNewSuggestionReplacesItsOwn() {
        let store = NominationsStore()
        var first = Data.proposal
        first.id = "p1"
        store.add(first, for: Data.lumen)
        var second = Data.proposal
        second.id = "p2"
        #expect(store.add(second, for: Data.lumen) == ["p1"])
        var other = Data.proposal
        other.id = "p3"
        other.evidence.client = "Codex"
        #expect(store.add(other, for: Data.lumen).isEmpty)
        #expect(store.proposals(for: Data.lumen).map(\.id) == ["p2", "p3"])
        #expect(store.count(for: Data.lumen) == 2)
    }

    @Test func requestsAreCountedAndReplacedPerAction() {
        let store = NominationsStore()
        let evidence = AssistantEvidence(client: Data.client, summary: "Lumen", why: "Starts soon.", evidence: [])
        let request = NominationActionRequest(id: "r1", nominationID: Data.draftID, action: .submit, evidence: evidence, receivedAt: Data.now)
        store.add(request, for: Data.lumen)
        var again = request
        again.id = "r2"
        #expect(store.add(again, for: Data.lumen) == ["r1"])
        #expect(store.actionRequests(for: Data.lumen, nominationID: Data.draftID).map(\.id) == ["r2"])
        #expect(store.count(for: Data.lumen) == 1)
    }

    @Test func aPushedDraftGivesWayToAppStoreConnects() throws {
        let store = NominationsStore()
        store.save(Data.draft, for: Data.lumen)
        store.noteQueued(Data.draftID, at: Data.now, for: Data.lumen)
        var created = Data.draft
        created.id = "N9"
        created.createdDate = Data.now.addingTimeInterval(30)
        // Its Create row still waits: the draft stays.
        let create = try NominationChangeBuilder(appID: Data.lumen).create(Data.draft)
        store.reconcile(remote: [created], changes: [create], for: Data.lumen)
        #expect(store.drafts(for: Data.lumen).count == 1)
        // Pushed: App Store Connect's takes its place.
        store.reconcile(remote: [created], changes: [], for: Data.lumen)
        #expect(store.drafts(for: Data.lumen).isEmpty)
    }

    @Test func requestsAboutNominationsThatMovedOnGo() {
        let store = NominationsStore()
        let evidence = AssistantEvidence(client: Data.client, summary: "Winter", why: "It’s over.", evidence: [])
        store.add(NominationActionRequest(id: "r1", nominationID: Data.winterID, action: .archive, evidence: evidence, receivedAt: Data.now), for: Data.lumen)
        store.reconcile(remote: [Data.winter], changes: [], for: Data.lumen)
        #expect(store.actionRequests(for: Data.lumen).count == 1)
        var archived = Data.winter
        archived.state = .archived
        store.reconcile(remote: [archived], changes: [], for: Data.lumen)
        #expect(store.actionRequests(for: Data.lumen).isEmpty)
    }

    @Test func dismissedBuiltInsCanComeBack() {
        let store = NominationsStore()
        store.dismissBuiltIn("draft.type", for: Data.lumen)
        #expect(store.isDismissed("draft.type", for: Data.lumen))
        store.restoreBuiltIn("draft.type", for: Data.lumen)
        #expect(!store.isDismissed("draft.type", for: Data.lumen))
    }
}
