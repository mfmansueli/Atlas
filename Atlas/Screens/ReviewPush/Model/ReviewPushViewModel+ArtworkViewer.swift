//
//  ReviewPushViewModel+ArtworkViewer.swift
//  Atlas
//

import Foundation

/// The review list's viewer for event art: a click on a change's image or
/// video opens it large, with every other art change of the list a ← →
/// away. A movie plays muted on repeat.
extension ReviewPushViewModel {
    /// Opens the art of the change with `changeID`.
    func openArtwork(of changeID: PendingChange.ID) {
        let items = artworkViewerItems
        guard let index = items.firstIndex(where: { $0.id == Self.artworkViewerID(changeID) }) else { return }
        viewer = ReviewViewer(items: items, index: index)
    }

    /// Every art change the list shows, in its order.
    var artworkViewerItems: [ReviewViewerItem] {
        appGroups.flatMap(\.groups).flatMap(\.plainChanges).compactMap(Self.artworkViewerItem)
    }

    /// "Gratitude Week · German": "Event details · 9:16 · Video (0:20) ·
    /// 1080 × 1920 · details-de.mp4"; nil for a change without art.
    static func artworkViewerItem(_ change: PendingChange) -> ReviewViewerItem? {
        guard let artwork = change.requests.lazy.compactMap(InAppEventArtworkPush.init).first else { return nil }
        let file = ReviewViewerFile(
            url: URL(fileURLWithPath: artwork.path), isVideo: artwork.isVideo, pixelSize: InAppEventArtworkRules.minimumSize(for: artwork.kind)
        )
        let parts = ["\(artwork.kind.title) · \(artwork.kind.ratioTitle)", change.newValue].filter { !$0.isEmpty }
        return ReviewViewerItem(
            id: artworkViewerID(change.id), title: "\(change.group) · \(change.title)", subtitle: parts.joined(separator: " · "),
            content: .file(file)
        )
    }

    static func artworkViewerID(_ changeID: PendingChange.ID) -> String {
        "review.artwork.\(changeID)"
    }
}
