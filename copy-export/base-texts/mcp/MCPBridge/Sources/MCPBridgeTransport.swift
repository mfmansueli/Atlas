//
//  MCPBridgeTransport.swift
//  atlas-mcp
//

import Foundation

/// Sends the bridge's HTTP requests: `URLSession` in the tool, a fake in
/// tests.
protocol MCPBridgeTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)

    /// A reply read as it arrives, line by line (empty lines too: they end
    /// an event): the `GET` event stream Atlas asks the client on.
    func stream(_ request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>)
}
