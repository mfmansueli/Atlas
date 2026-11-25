//
//  LiveArtworkMemo.swift
//  Atlas
//

import Foundation

/// The live header and search artwork each preview last read, kept for
/// this launch like `LiveShotsMemo`: the Screenshots page, the Store Page
/// and the Overview draw them at once when shown again, and read again
/// behind them only when that's over a minute old. Previews asking at the
/// same time share one read.
@MainActor
final class LiveArtworkMemo {
    static let shared = LiveArtworkMemo()

    private struct Entry {
        var artwork: LiveStoreArtworkSet
        var readAt: Date
    }

    let freshFor: TimeInterval
    private let now: () -> Date
    private var entries: [LiveShotsMemo.Key: Entry] = [:]
    private var reads: [LiveShotsMemo.Key: Task<LiveStoreArtworkSet?, Never>] = [:]

    init(freshFor: TimeInterval = 60, now: @escaping () -> Date = { .now }) {
        self.freshFor = freshFor
        self.now = now
    }

    func kept(_ key: LiveShotsMemo.Key) -> LiveStoreArtworkSet? {
        entries[key]?.artwork
    }

    func needsRead(_ key: LiveShotsMemo.Key) -> Bool {
        guard let entry = entries[key] else { return true }
        return now().timeIntervalSince(entry.readAt) >= freshFor
    }

    /// A push changed the page: the next preview reads it again.
    func forget(appID: String) {
        entries = entries.filter { $0.key.appID != appID }
    }

    /// Reads `key` with `read`, sharing a read already on its way. When
    /// it fails, what was kept stands (nil if nothing was).
    func read(
        _ key: LiveShotsMemo.Key, with read: @escaping @MainActor () async throws -> LiveStoreArtworkSet
    ) async -> LiveStoreArtworkSet? {
        let task = reads[key] ?? Task { [weak self] in
            let artwork = try? await read()
            guard let self else { return artwork }
            reads[key] = nil
            guard let artwork else { return entries[key]?.artwork }
            entries[key] = Entry(artwork: artwork, readAt: now())
            return artwork
        }
        reads[key] = task
        return await task.value
    }
}
