//
//  MCPBridgeEventStreamTests.swift
//  AtlasTests
//

import Foundation
import Testing

@Suite("MCPBridgeEventStream")
struct MCPBridgeEventStreamTests {
    @Test func eachEventIsOneMessage() {
        let body = "id: 1\r\ndata: {\"a\":1}\r\n\r\n: keep-alive\n\nevent: message\ndata:{\"b\":2}\n\n"
        #expect(MCPBridgeEventStream.messages(in: Data(body.utf8)) == [#"{"a":1}"#, #"{"b":2}"#])
    }

    /// The event stream arrives line by line: a message once its event ends.
    @Test func theParserReadsAStreamAsItArrives() {
        var parser = MCPBridgeEventStream.Parser()
        #expect(parser.read(": keep-alive") == nil)
        #expect(parser.read("") == nil)
        #expect(parser.read("event: message") == nil)
        #expect(parser.read("data: {\"a\":1}\r") == nil)
        #expect(parser.read("\r") == #"{"a":1}"#)
        #expect(parser.read("") == nil)
    }

    @Test func dataLinesOfOneEventAreJoined() {
        #expect(MCPBridgeEventStream.messages(in: Data("data: {\"a\":\ndata: 1}\n\n".utf8)) == ["{\"a\":\n1}"])
    }
}
