//
//  MCPBridgeReachTests.swift
//  AtlasTests
//

import Foundation
import Testing

/// The bridge opening Atlas when it's closed, and carrying what Atlas asks
/// the client on the session's event stream.
@Suite("MCPBridge reaching Atlas")
struct MCPBridgeReachTests {
    private static let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#
    private static let initialized = #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#
    private static let listTools = #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#
    private static let initializeResult = #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","serverInfo":{"name":"Atlas"}}}"#
    private static let toolsResult = #"{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}"#
    private static let rootsRequest = #"{"jsonrpc":"2.0","id":"roots-1","method":"roots/list"}"#
    private static let rootsAnswer = #"{"jsonrpc":"2.0","id":"roots-1","result":{"roots":[{"uri":"file:///Users/me/Alba"}]}}"#
    private static let refused = Result<FakeBridgeTransport.Reply, URLError>.failure(URLError(.cannotConnectToHost))
    private static let accepted = Result<FakeBridgeTransport.Reply, URLError>.success(.init(status: 202, headers: [:]))

    private static func session(_ id: String) -> Result<FakeBridgeTransport.Reply, URLError> {
        .success(.init(headers: ["Content-Type": "application/json", "Mcp-Session-Id": id], body: initializeResult))
    }

    private let pauses = LogLines()
    private let emitted = LogLines()

    private func bridge(_ transport: FakeBridgeTransport, launcher: FakeBridgeLauncher? = nil) -> MCPBridge {
        MCPBridge(
            options: MCPBridgeOptions(token: "al_tok"), transport: transport, launcher: launcher,
            pause: { [pauses] _ in pauses.append("pause") }, emit: { [emitted] in emitted.append($0) }
        )
    }

    /// The stream runs on its own task: waits until `condition` holds.
    private func eventually(_ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0..<400 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }

    // MARK: - Opening Atlas

    @Test func aClosedAtlasIsOpenedAndTheRequestWaitsForItsServer() async {
        let transport = FakeBridgeTransport([Self.refused, Self.refused, Self.session("s1")])
        let launcher = FakeBridgeLauncher(.starting)

        #expect(await bridge(transport, launcher: launcher).forward(Self.initialize) == [Self.initializeResult])
        #expect(launcher.opened == 1)
        #expect(pauses.all.count == 2)
        #expect(await transport.bodies == Array(repeating: Self.initialize, count: 3))
    }

    @Test func anAtlasOpenForAWhileIsntWaitedFor() async throws {
        let transport = FakeBridgeTransport([Self.refused])
        let launcher = FakeBridgeLauncher(.running)

        let reply = try #require(await bridge(transport, launcher: launcher).forward(Self.listTools).first)
        #expect(reply == MCPBridgeMessage.error(id: "2", code: MCPBridge.failureCode, message: MCPBridge.unreachable))
        #expect(launcher.opened == 1)
        #expect(pauses.all.isEmpty)
        #expect(await transport.requests.count == 1)
    }

    @Test func aServerThatNeverStartsIsWaitedForUpToTheLimit() async throws {
        let transport = FakeBridgeTransport([])
        let launcher = FakeBridgeLauncher(.starting)

        let reply = try #require(await bridge(transport, launcher: launcher).forward(Self.listTools).first)
        #expect(reply == MCPBridgeMessage.error(id: "2", code: MCPBridge.failureCode, message: MCPBridge.unreachable))
        let tries = Int(MCPBridge.launchWait / MCPBridge.retryInterval)
        #expect(pauses.all.count == tries)
        #expect(await transport.requests.count == tries + 1)
    }

    @Test func atlasThatCantBeOpenedAnswersAtOnce() async {
        let transport = FakeBridgeTransport([Self.refused])
        let launcher = FakeBridgeLauncher(.unavailable("Atlas isn’t installed on this Mac."))

        #expect(await bridge(transport, launcher: launcher).forward(Self.listTools).count == 1)
        #expect(pauses.all.isEmpty)
    }

    /// Anything but a refused connection may have reached Atlas: never sent twice.
    @Test func otherFailuresArentTriedAgain() async {
        let transport = FakeBridgeTransport([.failure(URLError(.networkConnectionLost))])
        let launcher = FakeBridgeLauncher(.starting)

        #expect(await bridge(transport, launcher: launcher).forward(Self.listTools).count == 1)
        #expect(launcher.opened == 0)
        #expect(await transport.requests.count == 1)
    }

    // MARK: - Event stream

    @Test func atlasQuestionsOnTheEventStreamReachTheClient() async throws {
        let transport = FakeBridgeTransport(
            [Self.session("s1"), Self.accepted, Self.accepted],
            streams: [.init(lines: [": open", "event: message", "data: \(Self.rootsRequest)", ""])]
        )
        let bridge = bridge(transport)
        _ = await bridge.forward(Self.initialize)
        #expect(await transport.streamRequests.isEmpty)

        _ = await bridge.forward(Self.initialized)
        let emitted = emitted
        let asked = await eventually { emitted.all == [Self.rootsRequest] }
        #expect(asked)
        let stream = try #require(await transport.streamRequests.first)
        #expect(stream.httpMethod == "GET")
        #expect(stream.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        #expect(stream.value(forHTTPHeaderField: "Mcp-Session-Id") == "s1")
        #expect(stream.value(forHTTPHeaderField: "Authorization") == "Bearer al_tok")

        // The client's answer is posted like any message, and needs none back.
        #expect(await bridge.forward(Self.rootsAnswer).isEmpty)
        #expect(await transport.bodies.last == Self.rootsAnswer)
    }

    @Test func aNewSessionGetsItsOwnStream() async {
        let transport = FakeBridgeTransport(
            [
                Self.session("s1"), Self.accepted,
                .success(.init(status: 404, headers: ["Content-Type": "text/plain"], body: "Unknown session")),
                Self.session("s2"), Self.accepted, .success(.init(body: Self.toolsResult)),
            ],
            streams: [.init(), .init(), .init()]
        )
        let bridge = bridge(transport)
        _ = await bridge.forward(Self.initialize)
        _ = await bridge.forward(Self.initialized)

        #expect(await bridge.forward(Self.listTools) == [Self.toolsResult])
        let reopened = await eventually { await transport.streamRequests.last?.value(forHTTPHeaderField: "Mcp-Session-Id") == "s2" }
        #expect(reopened)
    }

    @Test func aStreamAtlasRefusesIsntOpenedAgain() async {
        let toolsReply = Result<FakeBridgeTransport.Reply, URLError>.success(.init(body: Self.toolsResult))
        let transport = FakeBridgeTransport(
            [Self.session("s1"), Self.accepted, toolsReply, toolsReply],
            streams: [.init(status: 405), .init(status: 405)]
        )
        let bridge = bridge(transport)
        _ = await bridge.forward(Self.initialize)
        _ = await bridge.forward(Self.initialized)
        let opened = await eventually { await transport.streamRequests.count == 1 }
        #expect(opened)
        #expect(await bridge.streamSessionID == "s1")

        _ = await bridge.forward(Self.listTools)
        _ = await bridge.forward(Self.listTools)
        #expect(await transport.streamRequests.count == 1)
    }

    @Test func closingStopsTheStream() async {
        let transport = FakeBridgeTransport([Self.session("s1"), Self.accepted, .success(.init(status: 204, headers: [:]))], streams: [.init(status: 405)])
        let bridge = bridge(transport)
        _ = await bridge.forward(Self.initialize)
        _ = await bridge.forward(Self.initialized)

        await bridge.close()
        #expect(await bridge.streamSessionID == nil)
        #expect(await transport.requests.last?.httpMethod == "DELETE")
    }
}
