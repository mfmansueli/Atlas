//
//  NewInAppEventChangeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The change a new event waits in Review & Push as: the `POST
/// /v1/appEvents` with every attribute App Store Connect takes, its
/// languages created into `{createdID}`, what Review & Push shows, and the
/// event read back from the queue.
@MainActor
@Suite("InAppEventChangeBuilder · new event")
struct NewInAppEventChangeTests {
    typealias Data = InAppEventsTestData

    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    private func makeEvent() -> NewInAppEvent {
        var event = NewInAppEvent(now: Data.now)
        event.referenceName = "  Spring Reset 2027 "
        event.badge = .newSeason
        event.purpose = .bringBackLapsedUsers
        event.priority = .high
        event.purchaseRequirement = .inAppPurchase
        event.deepLink = " https://lumen.app/events/spring "
        event.texts["en-US"] = [.name: "Spring Reset", .shortDescription: "A fresh start", .longDescription: "Seven days of small habits."]
        event.texts["de-DE"] = [.name: "Frühlingsstart", .shortDescription: "", .longDescription: ""]
        event.texts["ja"] = [.name: "", .shortDescription: "", .longDescription: ""]
        return event
    }

    private static func attributes(_ change: PendingChange) throws -> [String: Any] {
        let body = try #require(change.requests.first?.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try #require((object["data"] as? [String: Any])?["attributes"] as? [String: Any])
    }

    @Test func theCreateRequestHasEveryAttribute() throws {
        let change = try #require(builder.newEventChange(makeEvent(), token: "t1"))
        #expect(change.id == "inAppEvents.\(Data.app.id).new-event.t1")
        #expect(change.requests.first?.method == .post)
        #expect(change.requests.first?.path == "/v1/appEvents")
        let attributes = try Self.attributes(change)
        #expect(attributes["referenceName"] as? String == "Spring Reset 2027")
        #expect(attributes["badge"] as? String == "NEW_SEASON")
        #expect(attributes["purpose"] as? String == "BRING_BACK_LAPSED_USERS")
        #expect(attributes["priority"] as? String == "HIGH")
        #expect(attributes["purchaseRequirement"] as? String == "IN_APP_PURCHASE")
        #expect(attributes["deepLink"] as? String == "https://lumen.app/events/spring")
        #expect(attributes["primaryLocale"] as? String == "en-US")
        let schedule = try #require((attributes["territorySchedules"] as? [[String: Any]])?.first)
        // Every territory App Store Connect has, filled in by the push.
        #expect(schedule["territories"] as? [String] == ["{everyTerritory}"])
        #expect(schedule["eventStart"] as? String == AppStoreConnectDate.text(makeEvent().eventStart))
        #expect(schedule["publishStart"] as? String == AppStoreConnectDate.text(makeEvent().publishStart))
    }

    @Test func withoutADeepLinkItIsLeftOutAndChosenTerritoriesAreKept() throws {
        var event = makeEvent()
        event.deepLink = ""
        event.territories = ["USA", "BRA"]
        let attributes = try Self.attributes(#require(builder.newEventChange(event)))
        #expect(attributes["deepLink"] == nil)
        #expect(attributes["purchaseRequirement"] as? String == "IN_APP_PURCHASE")
        #expect((attributes["territorySchedules"] as? [[String: Any]])?.first?["territories"] as? [String] == ["USA", "BRA"])
    }

    @Test func eachLanguageWithTextIsCreatedIntoTheNewEvent() throws {
        let change = try #require(builder.newEventChange(makeEvent()))
        // de-DE and en-US; ja has no text.
        #expect(change.requests.map(\.path) == ["/v1/appEvents", "/v1/appEventLocalizations", "/v1/appEventLocalizations"])
        let german = try #require(InAppEventWriteDocument.decode(change.requests[1].body))
        #expect(german.data.attributes == ["locale": "de-DE", "name": "Frühlingsstart"])
        #expect(german.data.relationships?["appEvent"]?.data == InAppEventWriteDocument.Identifier(type: "appEvents", id: PushRequest.createdIDPlaceholder))
        let english = try #require(InAppEventWriteDocument.decode(change.requests[2].body))
        #expect(english.texts == [.name: "Spring Reset", .shortDescription: "A fresh start", .longDescription: "Seven days of small habits."])
        #expect(english.data.relationships?["appEvent"]?.data.id == "{createdID}")
    }

    @Test func reviewAndPushShowsWhatItCreatesAndWhy() throws {
        let change = try #require(builder.newEventChange(
            makeEvent(), source: .assistant(client: "Claude Code"), reason: "Spring is when lapsed people come back.", evidence: ["Lumen/Events.swift:4"]
        ))
        #expect(change.title == "Create “Spring Reset 2027”")
        #expect(change.section == .inAppEvents)
        #expect(change.group == "In-App Events · New")
        #expect(change.source == .assistant(client: "Claude Code"))
        let creation = try #require(ReviewCreation.group([change]).first)
        #expect(creation.title == "Create “Spring Reset 2027”")
        #expect(creation.detail.contains("Add its event card and details page images in App Store Connect"))
        let fields = Dictionary(uniqueKeysWithValues: creation.fields.map { ($0.id, $0.newValue) })
        #expect(fields["event.badge"] == "New Season")
        #expect(fields["event.purchaseRequirement"] == "Needs an In-App Purchase")
        #expect(fields["event.deepLink"] == "https://lumen.app/events/spring")
        #expect(fields["event.territories"] == "All")
        #expect(fields["event.en-US.name"] == "Spring Reset")
        #expect(fields["event.reason"] == "Spring is when lapsed people come back.")
        #expect(fields["event.evidence"] == "Lumen/Events.swift:4")
        // It isn't a page: the heading counts it as a change.
        let group = ReviewChangeGroup(id: "g", title: change.group, section: .inAppEvents, groupID: nil, note: nil, changes: [change])
        #expect(group.countText == "1 change")
    }

    @Test func aQueuedEventIsReadBackAsItWasDescribed() throws {
        var original = makeEvent()
        original.texts["ja"] = nil
        original.texts["de-DE"] = [.name: "Frühlingsstart"]
        let change = try #require(builder.newEventChange(original))
        let read = try #require(InAppEventChangeBuilder.newEvent(in: change))
        #expect(read.referenceName == "Spring Reset 2027")
        #expect(read.badge == .newSeason)
        #expect(read.purpose == .bringBackLapsedUsers)
        #expect(read.priority == .high)
        #expect(read.purchaseRequirement == .inAppPurchase)
        #expect(read.deepLink == "https://lumen.app/events/spring")
        #expect(read.territories.isEmpty)
        #expect(read.eventStart == original.eventStart)
        #expect(read.eventEnd == original.eventEnd)
        #expect(read.publishStart == original.publishStart)
        #expect(read.texts == original.texts)
    }

    @Test func takenNamesAreTheEventsAndTheQueuedOnes() throws {
        let change = try #require(builder.newEventChange(makeEvent()))
        let taken = builder.takenReferenceNames(events: Data.events, changes: [change])
        #expect(taken == ["Winter Reflection 2026", "1.3 Weekly Review", "Gratitude Week", "Spring Reset 2027"])
        #expect(!builder.takenReferenceNames(events: [], changes: [change], except: change.id).contains("Spring Reset 2027"))
        #expect(builder.queuedNewEvent(named: "spring reset 2027", in: [change])?.id == change.id)
    }
}
