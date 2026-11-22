//
//  FakeBridgeTransport.swift
//  AtlasTests
//

import Foundation

/// Answers the bridge's requests from a script, oldest first, and keeps them.
actor FakeBridgeTransport: MCPBridgeTransport {
    /// One scripted reply.
    struct Reply {
        var status = 200
        var headers = ["Content-Type": "application/json"]
        var body = ""
    }

    /// One scripted event stream: its status and the lines it sends
    /// before it ends.
    struct Stream {
        var status = 200
        var lines: [String] = []
    }

    private var replies: [Result<Reply, URLError>]
    private var streams: [Stream]
    private(set) var requests: [URLRequest] = []
    /// The event streams the bridge opened, oldest first.
    private(set) var streamRequests: [URLRequest] = []

    init(_ replies: [Result<Reply, URLError>], streams: [Stream] = []) {
        self.replies = replies
        self.streams = streams
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.cannotConnectToHost) }
        let reply = try replies.removeFirst().get()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        return (Data(reply.body.utf8), response)
    }

    /// A refused connection once the script runs out, as when Atlas is
    /// closed.
    func stream(_ request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        streamRequests.append(request)
        guard !streams.isEmpty else { throw URLError(.cannotConnectToHost) }
        let stream = streams.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: stream.status, httpVersion: "HTTP/1.1", headerFields: [:])!
        return (response, AsyncThrowingStream { continuation in
            stream.lines.forEach { continuation.yield($0) }
            continuation.finish()
        })
    }

    /// The bodies the bridge posted, as text.
    var bodies: [String] {
        requests.map { String(bytes: $0.httpBody ?? Data(), encoding: .utf8) ?? "" }
    }
}
