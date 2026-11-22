//
//  URLSession+MCPBridgeTransport.swift
//  atlas-mcp
//

import Foundation

extension URLSession: MCPBridgeTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, response)
    }

    /// Split by hand: `AsyncBytes.lines` leaves out the empty lines that
    /// end each event.
    func stream(_ request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        let (bytes, response) = try await bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let lines = AsyncThrowingStream<String, any Error> { continuation in
            let reading = Task {
                var line: [UInt8] = []
                do {
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(String(bytes: line, encoding: .utf8) ?? "")
                            line.removeAll(keepingCapacity: true)
                        } else {
                            line.append(byte)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in reading.cancel() }
        }
        return (response, lines)
    }
}
