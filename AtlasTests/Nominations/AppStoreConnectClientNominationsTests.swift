//
//  AppStoreConnectClientNominationsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reading nominations from App Store Connect: the full query first, and
/// when Apple refuses one of its parameters, once more with the plain one.
@MainActor
@Suite("Nominations · client")
struct AppStoreConnectClientNominationsTests {
    private static let page = CannedHTTPResponse(body: NominationsDocumentTests.page)
    private static let refused = CannedHTTPResponse(statusCode: 400, body: """
    {"errors":[{"id":"e1","status":"400","code":"PARAMETER_ERROR.INVALID",
    "title":"A parameter has an invalid value","detail":"'actorType' is not a valid field name",
    "source":{"parameter":"fields[actors]"}}]}
    """)

    private func client(_ transport: FakeHTTPTransport) -> AppStoreConnectClient {
        AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
    }

    @Test func oneReadAsksForTheFullQuery() async throws {
        let transport = FakeHTTPTransport([Self.page])
        let pages = try await client(transport).nominations(state: "SUBMITTED", appID: "6450000001")
        #expect(pages.count == 1)
        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.url?.path() == "/v1/nominations")
        let expected = AppStoreConnectClient.nominationsQuery(state: "SUBMITTED", appID: "6450000001")
        #expect(query(request) == Dictionary(expected.map { ($0.name, $0.value ?? "") }) { first, _ in first })
        #expect(query(request)["fields[actors]"] == nil)
    }

    @Test func aRefusedParameterIsReadAgainPlain() async throws {
        let transport = FakeHTTPTransport([Self.refused, Self.page])
        let pages = try await client(transport).nominations(state: "SUBMITTED", appID: "6450000001")
        #expect(transport.requests.count == 2)
        let second = try query(#require(transport.requests.last))
        #expect(second["include"] == "relatedApps,inAppEvents,supportedTerritories")
        #expect(second["filter[state]"] == "SUBMITTED")
        #expect(second["filter[relatedApps]"] == "6450000001")
        #expect(!second.keys.contains { $0.hasPrefix("fields[") })
        let nomination = try #require(pages.first.flatMap { LiveNominationsServices.nominations(in: $0).first })
        #expect(nomination.content.appIDs == ["6450000001", "6450000006"])
    }

    @Test func otherRefusalsAreNotReadAgain() async {
        let forbidden = CannedHTTPResponse(statusCode: 403, body: #"{"errors":[{"status":"403","code":"FORBIDDEN_ERROR"}]}"#)
        let transport = FakeHTTPTransport([forbidden, Self.page])
        await #expect(throws: AppStoreConnectError.self) {
            try await client(transport).nominations(state: "DRAFT", appID: "6450000001")
        }
        #expect(transport.requests.count == 1)
    }

    @Test func aPlainReadThatFailsToo() async {
        let transport = FakeHTTPTransport([Self.refused, Self.refused])
        await #expect(throws: AppStoreConnectError.self) {
            try await client(transport).nominations(state: "DRAFT", appID: "6450000001")
        }
        #expect(transport.requests.count == 2)
    }

    @Test func onlyAParameterErrorCounts() {
        #expect(AppStoreConnectClient.isParameterError(.server(statusCode: 400, code: "PARAMETER_ERROR.INVALID", detail: nil)))
        #expect(AppStoreConnectClient.isParameterError(.server(statusCode: 400, code: "PARAMETER_ERROR", detail: nil)))
        #expect(!AppStoreConnectClient.isParameterError(.server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: nil)))
        #expect(!AppStoreConnectClient.isParameterError(.forbidden(detail: nil)))
        #expect(!AppStoreConnectClient.isParameterError(.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: nil)))
    }
}
