//
//  InAppEventArtworkFileInfo.swift
//  Atlas
//

import CryptoKit
import Foundation

/// What Atlas knows of an event art file beyond its bytes, kept beside it
/// (`InAppEventArtworkFiles.infoName`): the name it arrived with, its
/// SHA-256 (two languages with the same one get the same art), and where it
/// came from. Files kept before Atlas wrote this have none.
struct InAppEventArtworkFileInfo: Codable, Hashable, Sendable {
    /// The name it was given: the upload's `?name=`, the rendered page's,
    /// the chosen file's. Nil when it came without one.
    var originalName: String?
    /// The bytes' SHA-256, lowercase hex.
    var sha256: String
    var origin: InAppEventArtworkOrigin?
    var savedAt: Date?

    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// `originalName`, `sha256` and `origin`, for the MCP tools.
    var json: [String: JSONValue] {
        var object: [String: JSONValue] = ["sha256": .string(sha256)]
        if let originalName { object["originalName"] = .string(originalName) }
        if let origin { object["origin"] = origin.json }
        return object
    }
}
