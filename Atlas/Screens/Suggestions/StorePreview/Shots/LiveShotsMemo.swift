//
//  LiveShotsMemo.swift
//  Atlas
//

import Foundation

/// The live screenshots each App Store preview last read, kept for this
/// launch: a preview shown again (another section, another language, the
/// Overview after the Store Page) draws them at once instead of reading
/// every language's sets again. Older than `freshFor`, the preview still
/// draws them and reads again behind them; previews asking at the same
/// time share one read.
@MainActor
final class LiveShotsMemo {
    static let shared = LiveShotsMemo()

    /// What one read is for: the app and each language's version
    /// localization, so a new version reads its own sets.
    struct Key: Hashable {
        var appID: String
        var localizations: [StoreLocale: String]
    }

    private struct Entry {
        var live: LiveScreenshots
        var readAt: Date
    }

    /// How long a read stays current before the next preview reads again.
    let freshFor: TimeInterval
    private let now: () -> Date
    private var entries: [Key: Entry] = [:]
    private var reads: [Key: Task<LiveScreenshots?, Never>] = [:]

    init(freshFor: TimeInterval = 60, now: @escaping () -> Date = { .now }) {
        self.freshFor = freshFor
        self.now = now
    }

    /// The screenshots last read for `key`, however old.
    func kept(_ key: Key) -> LiveScreenshots? {
        entries[key]?.live
    }

    /// Whether a preview showing `key` should read again: nothing kept,
    /// or kept longer than `freshFor`.
    func needsRead(_ key: Key) -> Bool {
        guard let entry = entries[key] else { return true }
        return now().timeIntervalSince(entry.readAt) >= freshFor
    }

    /// Reads `key` with `read`, sharing a read already on its way. When it
    /// fails, what was kept stands (nil if nothing was).
    func read(_ key: Key, with read: @escaping @MainActor () async throws -> LiveScreenshots) async -> LiveScreenshots? {
        let task = reads[key] ?? Task { [weak self] in
            let live = try? await read()
            guard let self else { return live }
            reads[key] = nil
            guard let live else { return entries[key]?.live }
            entries[key] = Entry(live: live, readAt: now())
            return live
        }
        reads[key] = task
        return await task.value
    }
}
