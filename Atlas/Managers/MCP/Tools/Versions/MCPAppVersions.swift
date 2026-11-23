//
//  MCPAppVersions.swift
//  Atlas
//

import Foundation

/// An app's App Store versions as the version tools see them: the Store
/// Page's list (newest first, the live one per platform), the new
/// versions waiting in Review & Push, and, for `get_app_versions`, each
/// version's builds and the one attached to it.
@MainActor
struct MCPAppVersions {
    let app: StoreApp
    let versions: [StorePageVersion]
    let queued: [PendingChange]
    /// Each version's builds, by version id, once `loadingBuilds` read them.
    var builds: [StorePageVersion.ID: ReleaseVersionBuilds] = [:]
    /// Why a version's builds couldn't be read, by version id.
    var buildErrors: [StorePageVersion.ID: String] = [:]

    static func load(_ app: StoreApp, in context: MCPToolContext) async throws -> MCPAppVersions {
        let content = try await context.workspace.services.storePage.content(for: app, versionID: nil)
        let queued = NewAppVersionChangeBuilder(appID: app.id).queued(in: context.workspace.changes)
        return MCPAppVersions(app: app, versions: content.versions, queued: queued)
    }

    /// The same, with every version's builds read as the Submit sheet reads
    /// them (a version whose read fails says why instead).
    func loadingBuilds(in context: MCPToolContext) async -> MCPAppVersions {
        var loaded = self
        for version in versions {
            do {
                loaded.builds[version.id] = try await context.workspace.services.release.builds(
                    for: app, versionID: version.id, versionString: version.versionString, platform: version.platform
                )
            } catch {
                loaded.buildErrors[version.id] = error.localizedDescription
            }
        }
        return loaded
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
            "versions": .array(mine.map(versionJSON)),
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

    /// One version: its number and state, and when its builds were read,
    /// `builds` (newest first) and `attachedBuild`.
    private func versionJSON(_ version: StorePageVersion) -> JSONValue {
        var object: [String: JSONValue] = [
            "versionString": .string(version.versionString),
            "state": .string(version.state.title),
            "editable": .bool(version.isEditable),
            "live": .bool(version.state.isLive),
        ]
        if let read = builds[version.id] {
            object["builds"] = .array(read.builds.map { Self.json($0, attached: $0.id == read.attachedBuildID) })
            object["attachedBuild"] = if let attached = read.attached {
                Self.json(attached, attached: true)
            } else if let id = read.attachedBuildID {
                .object(["id": .string(id), "buildNumber": read.attachedBuildNumber.map(JSONValue.string) ?? .null, "attached": true])
            } else {
                .null
            }
        }
        if let error = buildErrors[version.id] { object["buildsError"] = .string(error) }
        return .object(object)
    }

    /// `{id, buildNumber, processingState, uploaded, expired, attached,
    /// usesNonExemptEncryption}`.
    static func json(_ build: ReleaseBuild, attached: Bool) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(build.id),
            "buildNumber": .string(build.number),
            "processingState": .string(build.processing.rawValue),
            "expired": .bool(build.isExpired),
            "attached": .bool(attached),
            "uploaded": build.uploaded.map { .string($0.formatted(.iso8601)) } ?? .null,
        ]
        if let uses = build.usesNonExemptEncryption { object["usesNonExemptEncryption"] = .bool(uses) }
        return .object(object)
    }
}
