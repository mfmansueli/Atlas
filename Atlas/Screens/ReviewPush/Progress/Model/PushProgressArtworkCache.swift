//
//  PushProgressArtworkCache.swift
//  Atlas
//

import Foundation

/// The event art each change of a push uploads, read from its request
/// once: the sheet redraws as each row moves, and a long push of event
/// videos would otherwise parse every request's JSON every time. A change
/// edited before a retry is read again.
@MainActor
final class PushProgressArtworkCache {
    private var found: [String: InAppEventArtworkPush?] = [:]

    func artwork(for item: PushItem) -> InAppEventArtworkPush? {
        guard let request = item.change.pushRequests.first else { return nil }
        let key = "\(item.id)|\(request.hashValue)"
        if let cached = found[key] { return cached }
        let artwork = InAppEventArtworkPush(request)
        found[key] = .some(artwork)
        return artwork
    }
}
