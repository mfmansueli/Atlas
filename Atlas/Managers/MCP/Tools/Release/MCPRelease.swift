//
//  MCPRelease.swift
//  Atlas
//

import Foundation

/// An app's versions on their way to the App Store as the release tools
/// see them: per platform, the one the Overview's version card follows
/// (being prepared or with App Review first, else the one on the App
/// Store), read as the card reads it.
@MainActor
struct MCPRelease {
    let app: StoreApp
    /// One per platform, in the Store Page's order.
    var statuses: [ReleaseStatus]

    /// Reads each platform's version (only `platform`'s when given). The
    /// platforms come from the Store Page's versions; without them, the
    /// one version the card would follow.
    static func load(_ app: StoreApp, platform: String?, in context: MCPToolContext) async throws -> MCPRelease {
        var platforms: [String?]
        if let platform {
            platforms = [platform]
        } else {
            let known = await (try? MCPAppVersions.load(app, in: context))?.platforms ?? []
            platforms = known.isEmpty ? [nil] : known.map(Optional.some)
        }
        var statuses: [ReleaseStatus] = []
        for platform in platforms {
            guard let status = try await context.workspace.services.release.status(for: app, platform: platform) else { continue }
            // A platform without versions gets another platform's.
            if let platform, let read = status.version.platform, read != platform { continue }
            guard !statuses.contains(where: { $0.version.id == status.version.id }) else { continue }
            statuses.append(status)
        }
        return MCPRelease(app: app, statuses: statuses)
    }

    /// `platform`'s version; without one, the first being prepared or on
    /// its way, else the first.
    func status(on platform: String?) -> ReleaseStatus? {
        if let platform { return statuses.first { $0.version.platform == platform || $0.version.platform == nil } }
        return statuses.first { $0.phase != .live } ?? statuses.first
    }

    /// `IOS` for "ios" or "iOS"; refuses a name that isn't a platform.
    static func platform(_ arguments: MCPToolArguments) throws -> String? {
        guard let name = try arguments.optionalString("platform") else { return nil }
        guard let known = MCPAppVersions.platform(named: name) else {
            throw MCPToolError.invalidArgument(name: "platform", expected: String(localized: "IOS, MAC_OS, VISION_OS or TV_OS"))
        }
        return known
    }
}
