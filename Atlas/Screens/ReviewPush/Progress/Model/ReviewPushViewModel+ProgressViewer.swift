//
//  ReviewPushViewModel+ProgressViewer.swift
//  Atlas
//

import Foundation

/// The push progress's viewer: a click on a row's thumbnail opens every
/// image and video of the push large, at that row (← → step through
/// them). Screenshots draw as in review; extras and event art are read
/// from their files, a movie plays muted on repeat.
extension ReviewPushViewModel {
    /// Opens the push's images and videos at the row with `id` (a
    /// `PushProgressEntry` ID).
    func openPushProgress(at id: String, artwork: @MainActor (PushItem) -> InAppEventArtworkPush?) {
        let items = Self.progressViewerItems(push: push, artwork: artwork)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        viewer = ReviewViewer(items: items, index: index)
    }

    /// Every image and video the push sends, in the order the sheet lists
    /// them.
    static func progressViewerItems(push: PushController, artwork: @MainActor (PushItem) -> InAppEventArtworkPush?) -> [ReviewViewerItem] {
        var items: [ReviewViewerItem] = []
        if push.phase != .idle {
            items += push.items.compactMap { item in artwork(item).map { viewerItem($0, of: item) } }
        }
        if let run = push.screenshots.run {
            items += run.items.map(viewerItem(upload:))
        }
        if let run = push.screenshots.extras.run {
            items += run.items.map { viewerItem($0, status: run.status(of: $0)) }
        }
        return items
    }

    /// "Summer Sale · German": "Event card · 16:9 · card-de.mp4 · Sending".
    static func viewerItem(_ artwork: InAppEventArtworkPush, of item: PushItem) -> ReviewViewerItem {
        let file = ReviewViewerFile(
            url: URL(fileURLWithPath: artwork.path), isVideo: artwork.isVideo, pixelSize: InAppEventArtworkRules.minimumSize(for: artwork.kind)
        )
        let parts = [
            "\(artwork.kind.title) · \(artwork.kind.ratioTitle)", artwork.fileName, PushProgressState(item.status).title,
        ]
        return ReviewViewerItem(
            id: PushProgressEntry.changeID(item.id), title: "\(item.change.title) · \(item.change.group)",
            subtitle: parts.joined(separator: " · "), content: .file(file)
        )
    }

    /// "Arabic · iPhone · 1": "1320 × 2868 · Uploading 64%".
    static func viewerItem(upload: ScreenshotUploadItem) -> ReviewViewerItem {
        let content = ReviewViewerContent.screenshot(upload.plan)
        let parts = [content.pixelSize(.new)?.title, upload.status.stepTitle].compactMap(\.self)
        return ReviewViewerItem(
            id: PushProgressEntry.shotID(upload.id), title: upload.title, subtitle: parts.joined(separator: " · "), content: content
        )
    }

    /// "German · Header 21:9": "3840 × 1646 · Processing", a movie's with
    /// "plays muted on repeat".
    static func viewerItem(_ item: ExtrasPushItem, status: ExtrasPushStatus) -> ReviewViewerItem {
        let isVideo = item.kind.media == .video
        let file = ReviewViewerFile(url: item.fileURL, isVideo: isVideo, pixelSize: item.pixelSize)
        let parts = [item.pixelSize.title, status.title, isVideo ? String(localized: "plays muted on repeat") : nil].compactMap(\.self)
        return ReviewViewerItem(
            id: PushProgressEntry.extraID(item.id), title: item.title, subtitle: parts.joined(separator: " · "), content: .file(file)
        )
    }
}
