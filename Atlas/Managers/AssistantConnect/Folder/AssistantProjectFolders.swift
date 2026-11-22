//
//  AssistantProjectFolders.swift
//  Atlas
//

import Foundation

/// The project folder Connect was given, per app and per assistant: its
/// path, and a security-scoped bookmark made while the sandbox lets Atlas
/// read it (right after the drop or the Open panel), so Atlas can open it
/// again after a relaunch. `defaults` nil keeps them in memory.
@MainActor
final class AssistantProjectFolders {
    static let pathsKey = "assistantConnect.projectFolders"
    static let bookmarksKey = "assistantConnect.projectFolderBookmarks"

    private let defaults: UserDefaults?
    private var paths: [String: String]
    private var bookmarks: [String: Data]

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        paths = (defaults?.dictionary(forKey: Self.pathsKey) as? [String: String]) ?? [:]
        bookmarks = (defaults?.dictionary(forKey: Self.bookmarksKey) as? [String: Data]) ?? [:]
    }

    static func key(_ assistant: ConnectableAssistant, _ appID: StoreApp.ID) -> String {
        "\(assistant.rawValue)/\(appID)"
    }

    /// Absolute path.
    func folder(for assistant: ConnectableAssistant, appID: StoreApp.ID) -> String? {
        paths[Self.key(assistant, appID)]
    }

    /// The last folder given to `assistant`, for any app.
    func anyFolder(for assistant: ConnectableAssistant) -> String? {
        paths.first { $0.key.hasPrefix(assistant.rawValue + "/") }?.value
    }

    /// Keeps `path` (nil forgets it) and a bookmark of `url`, the URL the
    /// sandbox gave access to.
    func remember(_ path: String?, url: URL?, for assistant: ConnectableAssistant, appID: StoreApp.ID) {
        let key = Self.key(assistant, appID)
        paths[key] = path
        bookmarks[key] = path == nil ? nil : url.flatMap(ProjectFolderPicker.bookmark(for:))
        defaults?.set(paths, forKey: Self.pathsKey)
        defaults?.set(bookmarks, forKey: Self.bookmarksKey)
    }

    /// The folder with the sandbox's permission, when a bookmark has it.
    func url(for assistant: ConnectableAssistant, appID: StoreApp.ID) -> URL? {
        let key = Self.key(assistant, appID)
        if let data = bookmarks[key] {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        return paths[key].map { URL(filePath: $0, directoryHint: .isDirectory) }
    }
}
