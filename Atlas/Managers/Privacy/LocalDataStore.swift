//
//  LocalDataStore.swift
//  Atlas
//

import Foundation

/// What Atlas keeps on this Mac, for Settings → Privacy & Data: the size
/// of what can be made again (rendered images, App Store ratings), clearing
/// it, and Remove All Keys and Data…. DEBUG scenes and the tests' host
/// share the person's container, so there nothing is ever deleted: the
/// calls are only counted.
@MainActor
final class LocalDataStore {
    static let shared = LocalDataStore()

    /// Made again when needed: renders and the ratings cache.
    let cachesDirectory: URL
    /// Where everything else Atlas keeps is: drafts, suggestions, history,
    /// runs. Only `supportItems` in it are removed, never the rest.
    let supportDirectory: URL

    /// Atlas's own files and folders in Application Support, by name.
    static let supportItems = [
        "Atlas", "AppPrivacy", "FieldSuggestions.json", "MachineTranslations.json", "PendingChanges.json", "PushHistory.json",
    ]
    let isLive: Bool
    private(set) var clearedCaches = 0
    private(set) var removedEverything = 0

    init(
        cachesDirectory: URL = URL.cachesDirectory.appending(path: "Atlas", directoryHint: .isDirectory),
        supportDirectory: URL = URL.applicationSupportDirectory,
        isLive: Bool = LocalDataStore.defaultIsLive
    ) {
        self.cachesDirectory = cachesDirectory
        self.supportDirectory = supportDirectory
        self.isLive = isLive
    }

    static var defaultIsLive: Bool {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return false }
        #endif
        return true
    }

    /// The caches' size in bytes, read off the main thread.
    func cacheSize() async -> Int64 {
        let directory = cachesDirectory
        return await Task.detached { LocalDataStore.size(of: directory) }.value
    }

    nonisolated static func size(of directory: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    func clearCaches() {
        clearedCaches += 1
        guard isLive else { return }
        try? FileManager.default.removeItem(at: cachesDirectory)
    }

    /// Every key in the Keychain (App Store Connect, AI providers, the
    /// paired assistants'), then every file and setting Atlas keeps.
    /// Nothing changes in App Store Connect. The caller quits after.
    func removeEverything(session: AppSession, translation: TranslationPreferences, server: MCPServerController) {
        removedEverything += 1
        guard isLive else { return }
        for key in session.keys {
            try? session.remove(keyID: key.keyID)
        }
        try? translation.removeAllAPIKeys()
        for client in server.pairedClients {
            server.revoke(client.id)
        }
        for name in Self.supportItems {
            try? FileManager.default.removeItem(at: supportDirectory.appending(path: name))
        }
        try? FileManager.default.removeItem(at: cachesDirectory)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }
}
