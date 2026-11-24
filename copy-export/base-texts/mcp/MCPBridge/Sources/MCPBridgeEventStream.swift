//
//  MCPBridgeEventStream.swift
//  atlas-mcp
//

import Foundation

/// Reads a `text/event-stream` reply: each event's `data:` lines joined, one
/// JSON-RPC message per event.
enum MCPBridgeEventStream {
    /// Reads a stream line by line, as it arrives.
    struct Parser {
        private var data: [String] = []

        /// The event `line` ends (a blank line after `data:` lines), or nil.
        mutating func read(_ line: String) -> String? {
            let line = line.hasSuffix("\r") ? String(line.dropLast()) : line
            if line.isEmpty {
                defer { data = [] }
                return data.isEmpty ? nil : data.joined(separator: "\n")
            }
            if line.hasPrefix("data:") {
                let value = line.dropFirst("data:".count)
                data.append(value.hasPrefix(" ") ? String(value.dropFirst()) : String(value))
            }
            return nil
        }
    }

    /// Every message of a whole reply.
    static func messages(in body: Data) -> [String] {
        // "\r\n" is one Character: split after making it "\n".
        let text = (String(bytes: body, encoding: .utf8) ?? "").replacingOccurrences(of: "\r\n", with: "\n")
        var parser = Parser()
        return (text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) + [""]).compactMap { parser.read($0) }
    }
}
