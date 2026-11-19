//
//  MCPAppVersions.swift
//  Atlas
//

import Foundation

/// An app's App Store versions as the version tools see them: the Store
/// Page's list (newest first, the live one per platform), and the new
/// versions waiting in Review & Push.
@MainActor
struct MCPAppVersions {
    let app: StoreApp
    let versions: [StorePageVersion]
    let queued: [PendingChange]

    static func load(_ app: StoreApp, in context: MCPToolContext) async throws -> MCPAppVersions {
        let content = try await context.workspace.services.storePage.content(for: app, versionID: nil)
        let queued = NewAppVersionChangeBuilder(appID: app.id).queued(in: context.workspace.changes)
        return MCPAppVersions(app: app, versions: content.versions, queued: queued)
    }

    var platforms: [String] { NewAppVersionRules.platforms(in: versions) }

    /// The new version queued for `platform`, with its change.
    func queued(on platform: String) -> (change: PendingChange, version: NewAppVersion)? {
        for change in queued {
            if let version = NewAppVersionChangeBuilder.version(of: change), version.platform == platform { return (change, version) }
        }
        return nil
    }

    /// `IOS` for "ios", "iOS" or "IOS"; `MAC_OS` for "macOS". Nil for a
    /// name that isn't a platform.
    static func platform(named name: String) -> String? {
        let key = name.uppercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
        return switch key {
        case "IOS", "IPHONE", "IPAD": "IOS"
        case "MACOS", "MAC": "MAC_OS"
        case "VISIONOS", "VISION": "VISION_OS"
        case "TVOS", "TV": "TV_OS"
        default: nil
        }
    }

    /// One platform for `get_app_versions`.
    func json(for platform: String) -> JSONValue {
        let mine = versions.filter { $0.platform == platform }
        let inProgress = NewAppVersionRules.inProgress(on: platform, in: versions)
        var object: [String: JSONValue] = [
            "platform": .string(platform),
            "title": .string(StorePageVersion.title(ofPlatform: platform) ?? platform),
            "versions": .array(mine.map { version in
                [
                    "versionString": .string(version.versionString),
                    "state": .string(version.state.title),
                    "editable": .bool(version.isEditable),
                    "live": .bool(version.state.isLive),
                ]
            }),
            "latest": NewAppVersionRules.latest(on: platform, in: versions).map { .string($0.versionString) } ?? .null,
            "suggestedNext": .string(NewAppVersionRules.suggestedNumber(on: platform, in: versions)),
            "queued": queued(on: platform).map { .string($0.version.versionString) } ?? .null,
        ]
        if let inProgress {
            object["canCreate"] = false
            object["whyNot"] = .string(NewAppVersionProblem.inProgress(versionString: inProgress.versionString, state: inProgress.state).message)
        } else {
            object["canCreate"] = true
        }
        return .object(object)
    }
}
