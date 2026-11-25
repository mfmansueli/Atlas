//
//  InAppEventMediaMemory.swift
//  Atlas
//

import Foundation

/// Each event language's images and video as the last read that worked
/// found them. Media is read language by language (two requests each), and
/// one that fails (a rate limit, the network) would otherwise leave that
/// language without art until the next read: its card on the App Store
/// preview fell back to the gradient. A failed language keeps what it had.
@MainActor
final class InAppEventMediaMemory {
    private var media: [String: [InAppEventMedia]] = [:]

    nonisolated init() {}

    /// `read` by localization id, nil where reading that language's media
    /// failed: what worked is kept and returned, and a failed language gets
    /// what it had before (left out when it never had a read that worked).
    func settle(_ read: [String: [InAppEventMedia]?]) -> [String: [InAppEventMedia]] {
        var settled: [String: [InAppEventMedia]] = [:]
        for (id, found) in read {
            if let found {
                media[id] = found
                settled[id] = found
            } else if let kept = media[id] {
                settled[id] = kept
            }
        }
        return settled
    }
}
