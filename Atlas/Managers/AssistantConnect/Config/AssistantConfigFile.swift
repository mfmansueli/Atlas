//
//  AssistantConfigFile.swift
//  Atlas
//

import Foundation

/// An assistant's MCP settings file (`claude_desktop_config.json`,
/// `~/.cursor/mcp.json`): Atlas's entry under `mcpServers`, put in or
/// taken out, with everything else in the file left as it was. A file
/// that isn't a JSON object is never overwritten.
enum AssistantConfigFile {
    enum Problem: LocalizedError, Equatable {
        /// The file is there but isn't a JSON object.
        case unreadable(fileName: String)

        var errorDescription: String? {
            switch self {
            case let .unreadable(fileName):
                String(localized: "\(fileName) isn’t a settings file Atlas can read, so it was left as it is.")
            }
        }
    }

    /// The entry that connects with `token`: the stdio bridge, which opens
    /// Atlas when it's closed. Claude for Mac and Cursor both start it.
    static func entry(token: String, bridgePath: String) -> [String: Any] {
        ["command": bridgePath, "args": ["--token", token]]
    }

    /// `existing` (nil when there's no file yet) with `entry` as
    /// `mcpServers.<name>`.
    static func adding(_ entry: [String: Any], named name: String = MCPEndpoint.serverName, to existing: Data?, fileName: String) throws -> Data {
        var root = try object(in: existing, fileName: fileName)
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[name] = entry
        root["mcpServers"] = servers
        return try encoded(root)
    }

    /// `existing` without `mcpServers.<name>`; nil when there's nothing to
    /// take out.
    static func removing(named name: String = MCPEndpoint.serverName, from existing: Data?, fileName: String) throws -> Data? {
        guard existing != nil else { return nil }
        var root = try object(in: existing, fileName: fileName)
        guard var servers = root["mcpServers"] as? [String: Any], servers[name] != nil else { return nil }
        servers[name] = nil
        root["mcpServers"] = servers
        return try encoded(root)
    }

    /// The token in `mcpServers.<name>`, if the file has Atlas's entry.
    static func token(named name: String = MCPEndpoint.serverName, in data: Data?) -> String? {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = (root["mcpServers"] as? [String: Any])?[name] as? [String: Any],
              let arguments = entry["args"] as? [String],
              let index = arguments.firstIndex(of: "--token"), arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }

    private static func object(in data: Data?, fileName: String) throws -> [String: Any] {
        guard let data, !data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Problem.unreadable(fileName: fileName)
        }
        return object
    }

    private static func encoded(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(0x0A)
        return data
    }
}
