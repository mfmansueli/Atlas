//
//  MCPVersionTarget.swift
//  Atlas
//

import Foundation

/// The version a tool's `version` argument names: the one being prepared
/// (nil, as when it's left out), or a new version waiting in Review &
/// Push, which counts as being prepared until it's pushed. Anything else
/// is refused with what to do.
@MainActor
enum MCPVersionTarget {
    static func queued(
        _ version: String?,
        app: StoreApp,
        shown: String?,
        versions: [StorePageVersion],
        in workspace: MCPWorkspace
    ) throws -> QueuedAppVersion? {
        guard let version, version != shown else { return nil }
        if let queued = QueuedAppVersion.all(for: app.id, in: workspace.changes).first(where: { $0.versionString == version }) {
            return queued
        }
        throw MCPToolError.notFound(message(for: version, app: app.name, shown: shown, inAppStoreConnect: versions.contains { $0.versionString == version }))
    }

    /// Why `version` can't be read or written.
    static func message(for version: String, app: String, shown: String?, inAppStoreConnect: Bool) -> String {
        if inAppStoreConnect, let shown {
            return String(localized: "\(app)’s version being prepared is \(shown), not \(version), which can’t change anymore. Texts are for \(shown).")
        }
        return String(localized: "\(version) isn’t in App Store Connect or queued in Atlas for \(app); propose it with propose_app_version first, then its texts for it.")
    }
}
