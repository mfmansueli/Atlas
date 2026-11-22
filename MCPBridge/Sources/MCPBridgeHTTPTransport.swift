//
//  MCPBridgeHTTPTransport.swift
//  atlas-mcp
//

import Foundation

/// The tool's transport. The bridge opens Atlas, and sends a message again,
/// only for a refused connection, since nothing was sent then. URLSession
/// can't be trusted to say so: a kept-alive connection to an Atlas that
/// quit fails as "connection lost", and once the process has used the port
/// even a new connection that's refused does too. So each message goes on a
/// new connection (a kept one can't tell a quit Atlas from a lost request),
/// and "connection lost" with nothing listening on the port is reported as
/// refused. The event stream is one long request on its own session.
struct MCPBridgeHTTPTransport: MCPBridgeTransport {
    private let streaming = URLSession(configuration: .ephemeral)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        do {
            return try await session.send(request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            if let url = request.url, !MCPBridgePortProbe.isListening(url) { throw URLError(.cannotConnectToHost) }
            throw error
        }
    }

    func stream(_ request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        try await streaming.stream(request)
    }
}
