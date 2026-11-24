//
//  NominationRequestBodyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Atlas sends App Store Connect for a nomination: a draft created with
/// `submitted: false`, an update that clears what was removed, and submit
/// and archive as their own one-attribute requests.
@Suite("Nominations · request bodies")
struct NominationRequestBodyTests {
    typealias Data = DebugNominationsData

    private static func object(_ data: Foundation.Data) throws -> [String: Any] {
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["data"] as? [String: Any])
    }

    private static func ids(_ relationship: Any?) -> [String] {
        ((relationship as? [String: Any])?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
    }

    @Test func aNewDraftIsCreatedNotSubmitted() throws {
        let data = try Self.object(NominationRequestBody.create(Data.draft.content))
        #expect(data["type"] as? String == "nominations")
        #expect(data["id"] == nil)
        let attributes = try #require(data["attributes"] as? [String: Any])
        #expect(attributes["submitted"] as? Bool == false)
        #expect(attributes["name"] as? String == "Lumen 1.4: Weekly reflections")
        #expect(attributes["type"] as? String == "APP_ENHANCEMENTS")
        #expect(attributes["publishStartDate"] as? String == AppStoreConnectDate.text(Data.day(2026, 12, 3)))
        #expect(attributes["deviceFamilies"] as? [String] == ["IPHONE", "IPAD"])
        #expect(attributes["hasInAppEvents"] as? Bool == true)
        #expect(attributes["supplementalMaterialsUris"] as? [String] == [Data.appStorePage])
        #expect(attributes["publishEndDate"] == nil)
        let relationships = try #require(data["relationships"] as? [String: Any])
        #expect(Self.ids(relationships["relatedApps"]) == [Data.lumen])
        #expect(Self.ids(relationships["inAppEvents"]) == [DebugInAppEventsData.winterID])
    }

    @Test func everyCountryOrRegionSendsNoTerritories() throws {
        let everywhere = try Self.object(NominationRequestBody.create(Data.draft.content))
        #expect((everywhere["relationships"] as? [String: Any])?["supportedTerritories"] == nil)
        var some = Data.draft.content
        some.territories = ["USA", "GBR"]
        let data = try Self.object(NominationRequestBody.create(some))
        #expect(Self.ids((data["relationships"] as? [String: Any])?["supportedTerritories"]) == ["USA", "GBR"])
    }

    @Test func aDraftWithoutEventsSendsNoEventLinkage() throws {
        var content = Data.draft.content
        content.eventIDs = []
        let data = try Self.object(NominationRequestBody.create(content))
        #expect((data["relationships"] as? [String: Any])?["inAppEvents"] == nil)
        #expect((data["attributes"] as? [String: Any])?["hasInAppEvents"] as? Bool == false)
    }

    @Test func anUpdateClearsWhatWasRemoved() throws {
        var content = Data.draft.content
        content.eventIDs = []
        content.materials = []
        content.notes = ""
        let data = try Self.object(NominationRequestBody.update(id: "N1", content))
        #expect(data["id"] as? String == "N1")
        let attributes = try #require(data["attributes"] as? [String: Any])
        #expect(attributes["submitted"] == nil)
        #expect(attributes["publishEndDate"] is NSNull)
        #expect(attributes["supplementalMaterialsUris"] as? [String] == [])
        #expect(attributes["notes"] as? String == "")
        let relationships = try #require(data["relationships"] as? [String: Any])
        #expect(Self.ids(relationships["inAppEvents"]).isEmpty)
        #expect(relationships["inAppEvents"] != nil)
        #expect(Self.ids(relationships["supportedTerritories"]).count == TerritoryCatalog.standard.count)
    }

    @Test func submitAndArchiveSendOneAttribute() throws {
        let submit = try #require(String(bytes: NominationRequestBody.submit(id: "N1"), encoding: .utf8))
        #expect(submit == #"{"data":{"attributes":{"submitted":true},"id":"N1","type":"nominations"}}"#)
        let archive = try #require(String(bytes: NominationRequestBody.archive(id: "N1"), encoding: .utf8))
        #expect(archive == #"{"data":{"attributes":{"archived":true},"id":"N1","type":"nominations"}}"#)
    }

    @Test func linksKeepTheirSlashes() throws {
        let text = try #require(String(bytes: NominationRequestBody.create(Data.draft.content), encoding: .utf8))
        #expect(text.contains("https://apps.apple.com/app/id"))
    }
}
