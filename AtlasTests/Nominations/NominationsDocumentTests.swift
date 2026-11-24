//
//  NominationsDocumentTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reading `GET /v1/nominations`: the query asks for one state of one app
/// with what the gallery shows, and a page, shaped as API 4.6.1 answers it,
/// maps to nominations with their apps', events' and people's names from
/// `included`.
@MainActor
@Suite("Nominations · reading App Store Connect")
struct NominationsDocumentTests {
    static let page = """
    {"data":[{"type":"nominations","id":"N1","attributes":{
      "name":"Lumen 1.3: Winter Journaling","type":"NEW_CONTENT","description":"A week of prompts.",
      "state":"SUBMITTED","publishStartDate":"2026-12-15T08:00:00Z","publishEndDate":"2026-12-22T08:00:00Z",
      "deviceFamilies":["IPHONE","IPAD","TOASTER"],"locales":["en-US","de-DE"],
      "supplementalMaterialsUris":["https://lumen.app/press"],"hasInAppEvents":true,
      "launchInSelectMarketsFirst":false,"preOrderEnabled":false,"notes":"Built around the event.",
      "createdDate":"2026-11-10T10:00:00Z","lastModifiedDate":"2026-11-20T10:00:00Z","submittedDate":"2026-11-20T10:00:00Z"},
     "relationships":{
      "relatedApps":{"meta":{"paging":{"total":2,"limit":50}},
       "data":[{"type":"apps","id":"6450000001"},{"type":"apps","id":"6450000006"}]},
      "createdByActor":{"data":{"type":"actors","id":"A1"}},
      "lastModifiedByActor":{"links":{"related":"https://api.appstoreconnect.apple.com/v1/nominations/N1/lastModifiedByActor"}},
      "submittedByActor":{"data":{"type":"actors","id":"A2"}},
      "inAppEvents":{"meta":{"paging":{"total":1,"limit":50}},"data":[{"type":"appEvents","id":"E1"}]},
      "supportedTerritories":{"meta":{"paging":{"total":2,"limit":200}},
       "data":[{"type":"territories","id":"USA"},{"type":"territories","id":"JPN"}]}},
     "links":{"self":"https://api.appstoreconnect.apple.com/v1/nominations/N1"}}],
     "included":[
      {"type":"apps","id":"6450000001","attributes":{"name":"Lumen"},
       "links":{"self":"https://api.appstoreconnect.apple.com/v1/apps/6450000001"}},
      {"type":"apps","id":"6450000006","attributes":{"name":"Quiet Timer"},
       "links":{"self":"https://api.appstoreconnect.apple.com/v1/apps/6450000006"}},
      {"type":"appEvents","id":"E1","attributes":{"referenceName":"Winter Journaling Week"},
       "links":{"self":"https://api.appstoreconnect.apple.com/v1/appEvents/E1"}},
      {"type":"territories","id":"USA","attributes":{"currency":"USD"}},
      {"type":"territories","id":"JPN","attributes":{"currency":"JPY"}},
      {"type":"actors","id":"A1","attributes":{"actorType":"USER","userFirstName":"Mateus","userLastName":"M",
       "userEmail":"mateus@example.com"},"links":{"self":"https://api.appstoreconnect.apple.com/v1/actors/A1"}},
      {"type":"actors","id":"A2","attributes":{"actorType":"API_KEY","apiKeyId":"KEY123"},
       "links":{"self":"https://api.appstoreconnect.apple.com/v1/actors/A2"}}],
     "links":{"self":"https://api.appstoreconnect.apple.com/v1/nominations?filter%5Bstate%5D=SUBMITTED"},
     "meta":{"paging":{"total":1,"limit":200}}}
    """

    @Test func aPageMapsToNominations() throws {
        let document = try JSONDecoder().decode(NominationsDocument.self, from: Data(Self.page.utf8))
        let nomination = try #require(LiveNominationsServices.nominations(in: document).first)
        #expect(nomination.id == "N1")
        #expect(nomination.state == .submitted)
        #expect(nomination.isInAppStoreConnect)
        #expect(!nomination.isEditable)
        let content = nomination.content
        #expect(content.type == .newContent)
        #expect(content.devices == [.iPhone, .iPad])
        #expect(content.locales == ["en-US", "de-DE"])
        #expect(content.territories == ["USA", "JPN"])
        #expect(content.eventIDs == ["E1"])
        #expect(content.appIDs == ["6450000001", "6450000006"])
        #expect(content.publishStart == AppStoreConnectDate.date("2026-12-15T08:00:00Z"))
        #expect(nomination.appNames["6450000006"] == "Quiet Timer")
        #expect(nomination.eventNames["E1"] == "Winter Journaling Week")
        #expect(nomination.createdBy == "Mateus")
        #expect(nomination.submittedBy == "API key KEY123")
    }

    @Test func actorsNameThePersonTheKeyOrWhoElse() throws {
        let json = """
        {"data":[],"included":[
          {"type":"actors","id":"U","attributes":{"actorType":"USER","userLastName":"Lima"}},
          {"type":"actors","id":"X","attributes":{"actorType":"XCODE_CLOUD"}},
          {"type":"actors","id":"P","attributes":{"actorType":"APPLE"}},
          {"type":"actors","id":"E","attributes":{"actorType":"USER","userFirstName":""}},
          {"type":"apps","id":"1","attributes":{"name":"Lumen"}}]}
        """
        let document = try JSONDecoder().decode(NominationsDocument.self, from: Data(json.utf8))
        #expect((document.included ?? []).map(\.actorName) == ["Lima", "Xcode Cloud", "Apple", nil, nil])
    }

    @Test func everyTerritoryReadsAsEverywhere() throws {
        let all = TerritoryCatalog.standard.territories.map { #"{"type":"territories","id":"\#($0.id)"}"# }.joined(separator: ",")
        let json = """
        {"data":[{"type":"nominations","id":"N2","attributes":{"name":"A","state":"DRAFT"},
        "relationships":{"supportedTerritories":{"data":[\(all)]}}}]}
        """
        let document = try JSONDecoder().decode(NominationsDocument.self, from: Data(json.utf8))
        let nomination = try #require(LiveNominationsServices.nominations(in: document).first)
        #expect(nomination.content.isEverywhere)
        #expect(nomination.state == .draft)
    }

    @Test func theQueryAsksForOneStateOfOneApp() {
        let items = AppStoreConnectClient.nominationsQuery(state: "DRAFT", appID: "6450000001")
        let query = Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
        #expect(query["filter[state]"] == "DRAFT")
        #expect(query["filter[relatedApps]"] == "6450000001")
        #expect(query["include"] == "relatedApps,inAppEvents,supportedTerritories,createdByActor,submittedByActor")
        #expect(query["fields[actors]"] == nil)
        #expect(query["limit"] == "200")
        #expect(AppStoreConnectClient.nominationStates == ["DRAFT", "SUBMITTED", "ARCHIVED"])
    }
}
