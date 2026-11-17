//
//  ComplianceContentLoaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The live services reading an app's countries and Apple's statuses from
/// canned App Store Connect JSON. Nothing reaches the network.
@MainActor
@Suite("ComplianceContentLoader")
struct ComplianceContentLoaderTests {
    private typealias Canned = AppInformationCannedResponses
    private let app = AppInformationTestSupport.app

    private static let availability = Canned.single(#"{"type":"appAvailabilities","id":"6450000001","attributes":{"availableInNewTerritories":true}}"#)

    private static func territory(_ id: String, _ territory: String?, available: Bool, statuses: [String]) -> String {
        let list = statuses.map { "\"\($0)\"" }.joined(separator: ",")
        let relationships = territory.map { #","relationships":{"territory":{"data":{"type":"territories","id":"\#($0)"}}}"# } ?? ""
        return #"{"type":"territoryAvailabilities","id":"\#(id)","attributes":{"available":\#(available),"contentStatuses":[\#(list)]}\#(relationships)}"#
    }

    private func services(_ transport: FakeHTTPTransport) -> LiveAppInformationServices {
        LiveAppInformationServices(
            client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport),
            notes: InMemoryAppInformationNotesStore(),
            privacy: InMemoryPrivacyWorksheetStore(),
            secrets: InMemorySecretStore()
        )
    }

    @Test func readsEachCountryWithApplesStatuses() async throws {
        let transport = FakeHTTPTransport([
            Self.availability,
            Canned.page([
                Self.territory("a-deu", "DEU", available: true, statuses: ["TRADER_STATUS_NOT_PROVIDED", "CANNOT_SELL"]),
                Self.territory("a-chn", "CHN", available: true, statuses: ["ICP_NUMBER_MISSING"]),
                Self.territory("a-vnm", "VNM", available: false, statuses: []),
            ]),
        ])
        let content = try await services(transport).compliance(for: app)

        #expect(content.territories?.count == 3)
        #expect(content.territory("DEU")?.id == "a-deu")
        #expect(content.territory("DEU")?.statuses == ["TRADER_STATUS_NOT_PROVIDED", "CANNOT_SELL"])
        #expect(content.territory("CHN")?.isAvailable == true)
        #expect(content.territory("VNM")?.isAvailable == false)
        #expect(TraderCheck(content) == .notProvided)
        #expect(ICPCheck(content) == .missing)

        let paths = transport.requests.compactMap(\.url?.path)
        #expect(paths == ["/v1/apps/6450000001/appAvailabilityV2", "/v2/appAvailabilities/6450000001/territoryAvailabilities"])
        #expect(transport.requests.allSatisfy { $0.httpMethod == "GET" })
        let query = try #require(transport.requests.last?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems)
        #expect(query.contains(URLQueryItem(name: "include", value: "territory")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "200")))
        #expect(query.contains(URLQueryItem(name: "fields[territoryAvailabilities]", value: "available,contentStatuses,territory")))
    }

    @Test func followsThePagesOfCountries() async throws {
        let first = CannedHTTPResponse(body: #"""
        {"data":[\#(Self.territory("a-usa", "USA", available: true, statuses: ["AVAILABLE"]))],\#
        "links":{"next":"https://api.appstoreconnect.apple.com/v2/appAvailabilities/6450000001/territoryAvailabilities?cursor=2"}}
        """#)
        let second = Canned.page([Self.territory("a-bra", "BRA", available: true, statuses: ["AVAILABLE"])])
        let transport = FakeHTTPTransport([Self.availability, first, second])
        let content = try await services(transport).compliance(for: app)
        #expect(content.territories?.map(\.territoryID) == ["USA", "BRA"])
        #expect(transport.requests.count == 3)
        #expect(transport.requests.last?.url?.query() == "cursor=2")
    }

    @Test func anAppWithoutAvailabilityHasNoCountriesToCheck() async throws {
        let transport = FakeHTTPTransport([Canned.notFound])
        let content = try await services(transport).compliance(for: app)
        #expect(content.territories == nil)
        #expect(transport.requests.count == 1)
    }

    @Test func aCountryWithoutItsLinkageIsReadFromTheID() async throws {
        // base64url of {"s":"6450000001","t":"CHN"}
        let id = "eyJzIjoiNjQ1MDAwMDAwMSIsInQiOiJDSE4ifQ"
        let transport = FakeHTTPTransport([
            Self.availability,
            Canned.page([
                Self.territory(id, nil, available: true, statuses: ["ICP_NUMBER_INVALID"]),
                Self.territory("opaque", nil, available: true, statuses: []),
            ]),
        ])
        let content = try await services(transport).compliance(for: app)
        #expect(content.territories?.map(\.territoryID) == ["CHN"])
        #expect(content.territory("CHN")?.id == id)
        #expect(ICPCheck(content) == .invalid)
    }

    @Test func aStatusThisBuildDoesNotKnowIsKept() async throws {
        let transport = FakeHTTPTransport([
            Self.availability,
            Canned.page([Self.territory("a-kor", "KOR", available: true, statuses: ["SOMETHING_NEW_FROM_APPLE"])]),
        ])
        let content = try await services(transport).compliance(for: app)
        #expect(content.territory("KOR")?.statuses == ["SOMETHING_NEW_FROM_APPLE"])
    }

    @Test func aFailureIsThrownForThePageToShow() async {
        let body = #"{"errors":[{"status":"500","code":"UNEXPECTED_ERROR","title":"Oops","detail":"Try later."}]}"#
        let failure = CannedHTTPResponse(statusCode: 500, body: body)
        await #expect(throws: AppStoreConnectError.self) {
            _ = try await services(FakeHTTPTransport([failure])).compliance(for: app)
        }
    }
}
