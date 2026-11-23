//
//  AssistantConfigAccess.swift
//  Atlas
//

import AppKit

/// The real settings files of Claude for Mac and Cursor. The sandbox lets
/// Atlas write outside its container only where the person chose to let
/// it, so the first Connect opens a panel on the assistant's settings
/// folder (already selected: one click on Allow), and Atlas keeps a
/// security-scoped bookmark of it for the next times.
@MainActor
final class AssistantConfigAccess: AssistantConfigWriting {
    static let bookmarksKey = "assistantConnect.configFolders"

    private let defaults: UserDefaults?
    private let home: String
    private let fileManager: FileManager
    /// Asks for the settings folder, starting in it; the folder chosen, or
    /// nil when the person cancelled.
    var folderAsker: @MainActor (_ assistant: ConnectableAssistant, _ folder: URL) -> URL? = AssistantConfigAccess.ask

    init(defaults: UserDefaults?, home: String = ProjectFolderPath.home, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.home = home
        self.fileManager = fileManager
    }

    /// `~/Library/Application Support/Claude`, `~/.cursor`.
    func folder(of assistant: ConnectableAssistant) -> URL? {
        assistant.configFolder.map { URL(filePath: home, directoryHint: .isDirectory).appending(path: $0, directoryHint: .isDirectory) }
    }

    func addAtlas(to assistant: ConnectableAssistant, token: String, bridgePath: String) throws {
        guard let fileName = assistant.configFileName else { return }
        let folder = try writableFolder(of: assistant)
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: fileName)
        let existing = fileManager.fileExists(atPath: file.path(percentEncoded: false)) ? try? Data(contentsOf: file) : nil
        let entry = AssistantConfigFile.entry(token: token, bridgePath: bridgePath)
        let data = try AssistantConfigFile.adding(entry, to: existing, fileName: fileName)
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            throw AssistantConfigProblem.writeFailed(
                AppleErrorCopy(String(localized: "Atlas couldn’t write \(assistant.title)’s settings.", comment: "kind:error"), error: error).text
            )
        }
    }

    func removeAtlas(from assistant: ConnectableAssistant) {
        guard let fileName = assistant.configFileName, let folder = bookmarkedFolder(of: assistant) else { return }
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let file = folder.appending(path: fileName)
        guard let data = try? AssistantConfigFile.removing(from: try? Data(contentsOf: file), fileName: fileName) else { return }
        try? data.write(to: file, options: .atomic)
    }

    // MARK: - The folder

    /// The bookmarked folder, else the one the person allows now.
    private func writableFolder(of assistant: ConnectableAssistant) throws -> URL {
        if let folder = bookmarkedFolder(of: assistant) { return folder }
        guard let expected = folder(of: assistant) else { throw AssistantConfigProblem.notAllowed(assistant) }
        guard fileManager.fileExists(atPath: expected.path(percentEncoded: false)) else {
            throw AssistantConfigProblem.folderMissing(assistant)
        }
        guard let chosen = folderAsker(assistant, expected) else { throw AssistantConfigProblem.notAllowed(assistant) }
        guard Self.standardized(chosen) == Self.standardized(expected) else {
            throw AssistantConfigProblem.wrongFolder(assistant, chosen: ProjectFolderPath.abbreviated(chosen.path(percentEncoded: false), home: home))
        }
        remember(chosen, for: assistant)
        return chosen
    }

    private func bookmarkedFolder(of assistant: ConnectableAssistant) -> URL? {
        guard let data = bookmarks[assistant.rawValue] else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return nil }
        if isStale { remember(url, for: assistant) }
        return url
    }

    private func remember(_ folder: URL, for assistant: ConnectableAssistant) {
        var all = bookmarks
        all[assistant.rawValue] = ProjectFolderPicker.bookmark(for: folder)
        defaults?.set(all, forKey: Self.bookmarksKey)
    }

    private var bookmarks: [String: Data] {
        (defaults?.dictionary(forKey: Self.bookmarksKey) as? [String: Data]) ?? [:]
    }

    private static func standardized(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    /// The Open panel, in the settings folder with it selected.
    static func ask(_ assistant: ConnectableAssistant, folder: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = folder
        panel.prompt = String(localized: "Allow")
        panel.message = String(localized: """
        This is \(assistant.title)’s settings folder. Click Allow; Atlas adds only its own entry.
        """)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
