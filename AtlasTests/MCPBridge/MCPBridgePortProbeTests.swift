//
//  MCPBridgePortProbeTests.swift
//  AtlasTests
//

import Darwin
import Foundation
import Testing

@Suite("MCPBridgePortProbe")
struct MCPBridgePortProbeTests {
    /// A socket listening on a free loopback port, and the port.
    private func listen() throws -> (socket: Int32, port: Int) {
        let listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        try #require(listener >= 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                bind(listener, generic, length) == 0 && Darwin.listen(listener, 1) == 0 && getsockname(listener, generic, &length) == 0
            }
        }
        try #require(bound)
        return (listener, Int(UInt16(bigEndian: address.sin_port)))
    }

    @Test func aListeningPortIsSeenAndAClosedOneIsnt() throws {
        let (listener, port) = try listen()
        let url = try #require(URL(string: "http://127.0.0.1:\(port)/mcp"))
        #expect(MCPBridgePortProbe.isListening(url))

        close(listener)
        #expect(!MCPBridgePortProbe.isListening(url))
    }

    @Test func aURLWithoutAPortCantBeTold() throws {
        #expect(try MCPBridgePortProbe.isListening(#require(URL(string: "http://127.0.0.1/mcp"))))
    }
}
