//
//  MCPStorePlatform.swift
//  Atlas
//

import Foundation

/// The listing tools' `platform` (ios, macos, visionos, tvos) and older
/// versions: which of App Store Connect's versions a call reads or writes,
/// as the Store Page's version picker opens one.
enum MCPStorePlatform {
    /// Argument names and App Store Connect's platforms.
    static let codes: [String: String] = ["ios": "IOS", "macos": "MAC_OS", "visionos": "VISION_OS", "tvos": "TV_OS"]

    static let schema = MCPToolDefinition.string("""
    ios, macos, visionos or tvos, when the app has several platforms: their versions and texts are separate. Leave it \
    out for the version the Store Page opens on (iOS first).
    """)

    /// "MAC_OS" for "macos" (or "MAC_OS"); throws for an unknown name.
    static func code(_ name: String) throws -> String {
        let lowered = name.lowercased().replacingOccurrences(of: "_", with: "")
        if let code = codes[lowered] { return code }
        throw MCPToolError.invalidArgument(name: "platform", expected: "ios, macos, visionos or tvos")
    }

    /// The version to load instead of `content`'s, or nil to keep it: the
    /// platform's own (its version being prepared, else its live one), or
    /// with `version` an existing one of that number (older versions are
    /// read-only). Throws for a platform the app doesn't have.
    static func version(platform: String?, version: String?, in content: StorePageContent, app: StoreApp) throws -> StorePageVersion? {
        let code = try platform.map(code)
        var candidates = content.versions.filter { !$0.isQueued }
        if let code {
            candidates = candidates.filter { $0.platform == code }
            guard !candidates.isEmpty else {
                let names = Set(content.versions.compactMap(\.platformTitle)).sorted().formatted(.list(type: .and))
                let wanted = StorePageVersion.title(ofPlatform: code) ?? code
                throw MCPToolError.notFound("\(app.name) has no \(wanted) version in App Store Connect. Its platforms: \(names).")
            }
        }
        if let version, version != content.version.versionString || code.map({ $0 != content.version.platform }) == true,
           let match = candidates.first(where: { $0.versionString == version })
        {
            return match
        }
        if let code, code != content.version.platform { return StorePageVersion.preferred(in: candidates) }
        return nil
    }

    /// Every version the picker lists, for `get_listing`'s `versions`.
    static func versionsJSON(_ content: StorePageContent) -> JSONValue {
        .array(content.versions.filter { !$0.isQueued }.map { version in
            var entry: [String: JSONValue] = [
                "versionString": .string(version.versionString),
                "state": .string(version.state.title),
                "editable": .bool(version.isEditable),
                "shown": .bool(version.id == content.version.id),
            ]
            if let platform = version.platform, let name = codes.first(where: { $0.value == platform })?.key {
                entry["platform"] = .string(name)
            }
            return .object(entry)
        })
    }
}
