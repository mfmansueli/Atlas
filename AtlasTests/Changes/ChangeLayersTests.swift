//
//  ChangeLayersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An assistant's details, how sure and gloss on the changes it queues:
/// put on its change, or on its version beside the person's, carried when
/// that version is picked, and absent from changes saved before.
@MainActor
@Suite("ChangeQueue · layers")
struct ChangeLayersTests {
    private static let assistant = ChangeSource.assistant(client: "Claude Code")
    private static let layers = SuggestionLayers(details: "12 of 40 reviews ask for it.", confidence: .fairlySure, gloss: "Your notes, private")

    private static func change(new: String, source: ChangeSource) -> PendingChange {
        PendingChange(
            id: "subtitle", appID: "1", section: .storePage, group: "Store Page", title: "German · Subtitle", oldValue: "old", newValue: new,
            source: source, requests: []
        )
    }

    @Test func theyGoOnTheAssistantsChange() {
        let queue = ChangeQueue()
        queue.upsert(Self.change(new: "Deine Notizen", source: Self.assistant))
        queue.attach(Self.layers, to: "subtitle")
        #expect(queue.change(id: "subtitle")?.layers == Self.layers)
    }

    @Test func theyNeverGoOnThePersonsChangeButOnTheAssistantsVersionBesideIt() throws {
        let queue = ChangeQueue()
        queue.upsert(Self.change(new: "Meine Notizen", source: .you))
        queue.attach(Self.layers, to: "subtitle")
        #expect(queue.change(id: "subtitle")?.layers == nil)

        queue.upsert(Self.change(new: "Deine Notizen", source: Self.assistant))
        queue.attach(Self.layers, to: "subtitle")
        let kept = try #require(queue.change(id: "subtitle"))
        #expect(kept.layers == nil)
        #expect(kept.alternative?.layers == Self.layers)

        queue.resolveAlternative(id: "subtitle", keepAlternative: true)
        let picked = try #require(queue.change(id: "subtitle"))
        #expect(picked.source == Self.assistant)
        #expect(picked.layers == Self.layers)
    }

    @Test func keepingThePersonsDropsThem() {
        let queue = ChangeQueue()
        queue.upsert(Self.change(new: "Meine Notizen", source: .you))
        queue.upsert(Self.change(new: "Deine Notizen", source: Self.assistant))
        queue.attach(Self.layers, to: "subtitle")
        queue.resolveAlternative(id: "subtitle", keepAlternative: false)
        #expect(queue.change(id: "subtitle")?.layers == nil)
    }

    @Test func noLayersLeaveTheChangeAsItIs() {
        let queue = ChangeQueue()
        queue.upsert(Self.change(new: "Deine Notizen", source: Self.assistant))
        queue.attach(Self.layers, to: "subtitle")
        queue.attach(nil, to: "subtitle")
        #expect(queue.change(id: "subtitle")?.layers == Self.layers)
    }

    @Test func aChangeSavedBeforeLayersStillDecodes() throws {
        var change = Self.change(new: "Deine Notizen", source: Self.assistant)
        change.layers = Self.layers
        change.alternative = ChangeAlternative(newValue: "B", source: Self.assistant, requests: [], layers: Self.layers)
        #expect(try JSONDecoder().decode(PendingChange.self, from: JSONEncoder().encode(change)) == change)

        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(change)) as? [String: Any])
        object.removeValue(forKey: "layers")
        var alternative = try #require(object["alternative"] as? [String: Any])
        alternative.removeValue(forKey: "layers")
        object["alternative"] = alternative
        let older = try JSONDecoder().decode(PendingChange.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(older.layers == nil)
        #expect(older.alternative?.layers == nil)
        #expect(older.newValue == "Deine Notizen")
    }

    @Test func aRetentionSuggestionSavedBeforeLayersStillDecodes() throws {
        let json = Data(#"{"messageID": "m1", "locale": "de-DE", "body": "Kurz.", "client": "Claude Code"}"#.utf8)
        let suggestion = try JSONDecoder().decode(RetentionSuggestion.self, from: json)
        #expect(suggestion.layers == nil)
        #expect(suggestion.body == "Kurz.")
    }

    @Test func aCreationShowsTheFirstLayersOfItsChanges() {
        var first = Self.change(new: "A", source: Self.assistant)
        first.creation = PendingCreation(id: "storePage.1.pl", title: "Create the Polish page", detail: "", source: Self.assistant, fields: [])
        var second = first
        second.id = "subtitle.2"
        second.layers = Self.layers
        #expect(ReviewCreation.group([first, second]).first?.layers == Self.layers)
    }
}
