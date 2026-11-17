//
//  EventArtworkUploadEndpointTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `POST /event-artwork/<token>/<app>`: an assistant sends a card or
/// details page made elsewhere, then names the returned file in
/// `render_event_artwork` or `propose_event_artwork`. This launch's token
/// is the link's only secret.
@MainActor
@Suite("In-App Event artwork upload link")
struct EventArtworkUploadEndpointTests {
    private let controller = MCPTestFixtures.controller()
    private let directory = EventArtworkTestFiles.directory()
    private static let appID = InAppEventsTestData.app.id

    init() {
        controller.workspace = MCPTestFixtures.workspace()
        controller.eventArtworkDirectory = directory
    }

    private func send(
        _ body: Data, token: String = InAppEventArtworkFiles.uploadToken, app: String = appID, query: String = "?name=card.png",
        method: String = "POST", headers: [String: String] = [:]
    ) async throws -> HTTPResponse {
        let allHeaders = ["Host": "127.0.0.1:47321"].merging(headers) { $1 }
        let target = "\(MCPEndpoint.eventArtworkPath)\(token)/\(app)\(query)"
        return try #require(await controller.handle(HTTPRequest(method: method, target: target, headers: allHeaders, body: body)).response)
    }

    @Test(arguments: ["POST", "PUT"])
    func anImageIsKeptUnderItsNameForTheTools(method: String) async throws {
        let response = try await send(EventArtworkTestFiles.png(width: 1920, height: 1080), method: method)
        #expect(response.status == 200)
        let json = try MCPTestFixtures.json(response)
        let fileID = try #require(json["fileId"]?.stringValue)
        #expect(json["fileName"] == "card.png")
        #expect(json["isVideo"] == false)
        #expect(json["pixelSize"] == "1920 × 1080")
        #expect(InAppEventArtworkFiles.url(id: fileID, appID: Self.appID, in: directory)?.lastPathComponent == "card.png")
    }

    @Test func aVideoIsKeptWithItsLength() async throws {
        let movie = try await EventArtworkTestFiles.movie(width: 1920, height: 1080, fps: 30, frames: 30, in: EventArtworkTestFiles.directory())
        let response = try await send(Data(contentsOf: movie), query: "?name=Gratitude%20loop.mov")
        #expect(response.status == 200)
        let json = try MCPTestFixtures.json(response)
        #expect(json["fileName"] == "Gratitude loop.mov")
        #expect(json["isVideo"] == true)
        #expect(json["seconds"]?.doubleValue == 1)
    }

    @Test func aWrongTokenAnEmptyBodyOrSomethingElseIsRefused() async throws {
        let unknown = try await send(EventArtworkTestFiles.png(width: 4, height: 4), token: "not-the-token")
        #expect(unknown.status == 404)
        #expect(try MCPTestFixtures.json(unknown) == ["error": "Unknown upload link; call get_in_app_events for this launch's link."])
        #expect(try await send(Data()).status == 400)
        let text = try await send(Data("hello".utf8), query: "?name=notes.txt")
        #expect(text.status == 422)
        let missingApp = try await send(EventArtworkTestFiles.png(width: 4, height: 4), app: "no-such-app")
        #expect(missingApp.status == 422)
    }

    @Test func onlyUploadsFromThisMacAreTaken() async throws {
        let png = EventArtworkTestFiles.png(width: 4, height: 4)
        #expect(try await send(png, headers: ["Origin": "https://evil.example"]).status == 403)
        #expect(try await send(png, headers: ["Host": "evil.example:47321"]).status == 403)
        let read = try await send(Data(), method: "GET")
        #expect(read.status == 405)
        #expect(HTTPRequestParser.maximumBodySize(for: "/event-artwork/x/1") == HTTPRequestParser.maximumUploadBodySize)
    }

    @Test func theLinkIsTheTokenAndTheAppOnTheServersPort() {
        #expect(MCPEndpoint.eventArtworkUploadURL(port: 4000, token: "t", appID: "42") == "http://127.0.0.1:4000/event-artwork/t/42")
        #expect(MCPServerController.queryValue("name", in: "/event-artwork/t/42?name=a%20b.png") == "a b.png")
    }
}
