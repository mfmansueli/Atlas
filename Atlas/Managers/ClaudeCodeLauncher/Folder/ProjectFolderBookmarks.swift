//
//  ProjectFolderBookmarks.swift
//  Atlas
//

import Foundation

/// Each app's project folder as a security-scoped bookmark, kept when the
/// person chooses it, so Atlas itself can read it after a relaunch (the
/// sandbox lets it read only what the person chose): the links the app
/// claims for In-App Events' deep links. Claude Code needs only the path.
@MainActor
struct ProjectFolderBookmarks {
    static let key = "claudeCode.projectFolderBookmarks"

    let defaults: UserDefaults?

    func bookmark(for appID: StoreApp.ID) -> Data? {
        (defaults?.dictionary(forKey: Self.key) as? [String: Data])?[appID]
    }

    /// Keeps a bookmark of `path` (nil forgets it). Made only while Atlas
    /// may read the folder: right after the Open panel.
    func remember(_ path: String?, for appID: StoreApp.ID) {
        set(path.flatMap { ProjectFolderPicker.bookmark(for: URL(filePath: $0, directoryHint: .isDirectory)) }, for: appID)
    }

    /// The folder to read: the bookmark's, which carries the sandbox's
    /// permission, else `path` itself (enough outside the sandbox, and
    /// while the Open panel's permission lasts).
    func url(for appID: StoreApp.ID, path: String) -> URL {
        var isStale = false
        guard let data = bookmark(for: appID),
              let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return URL(filePath: path, directoryHint: .isDirectory) }
        if isStale, let fresh = ProjectFolderPicker.bookmark(for: url) { set(fresh, for: appID) }
        return url
    }

    private func set(_ bookmark: Data?, for appID: StoreApp.ID) {
        guard let defaults else { return }
        var all = (defaults.dictionary(forKey: Self.key) as? [String: Data]) ?? [:]
        all[appID] = bookmark
        defaults.set(all, forKey: Self.key)
    }
}
