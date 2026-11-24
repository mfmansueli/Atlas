//
//  ReviewPushViewModel+ProgressViewer.swift
//  Atlas
//

import Foundation

/// The push progress's viewer: a click on a row's thumbnail opens every
/// image and video of the push large, at that row (← → step through
/// them). Screenshots draw as in review, with Live Now | New to compare a
/// slot's two sides (board 25); extras and event art are read from their
/// files, an App Preview plays with its sound (Sound Off mutes it) and a
/// motion loop plays muted on repeat.
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

    /// "Arabic · iPhone · 1": "1320 × 2868 · Uploading 64%", and on the
    /// live side what App Store Connect showed there before the push.
    static func viewerItem(upload: ScreenshotUploadItem) -> ReviewViewerItem {
        let content = ReviewViewerContent.screenshot(upload.plan)
        let parts = [content.pixelSize(.new)?.title, upload.status.stepTitle].compactMap(\.self)
        return ReviewViewerItem(
            id: PushProgressEntry.shotID(upload.id), title: upload.title, subtitle: parts.joined(separator: " · "),
            liveSubtitle: liveSubtitle(upload: upload, content: content), content: content
        )
    }

    /// "Live now on App Store Connect · 1320 × 2868", "Live until this
    /// push · …" once the push deleted it, or "Nothing live in this
    /// position: the push adds it".
    static func liveSubtitle(upload: ScreenshotUploadItem, content: ReviewViewerContent) -> String {
        guard upload.plan.old != nil else {
            return String(localized: "Nothing live in this position: the push adds it", comment: "kind:caption")
        }
        let lead = upload.isOldDeleted
            ? String(localized: "Live until this push", comment: "kind:caption")
            : String(localized: "Live now on App Store Connect", comment: "kind:caption")
        return [lead, content.pixelSize(.live)?.title].compactMap(\.self).joined(separator: " · ")
    }

    /// "German · Header 21:9": "3840 × 1646 · Processing", a motion loop's
    /// with "plays muted on repeat", an App Preview's with "click the video
    /// to play or pause" (it plays with its sound).
    static func viewerItem(_ item: ExtrasPushItem, status: ExtrasPushStatus) -> ReviewViewerItem {
        let isVideo = item.kind.media == .video
        let isAppPreview = if case .appPreview = item.kind { true } else { false }
        let file = ReviewViewerFile(url: item.fileURL, isVideo: isVideo, pixelSize: item.pixelSize, hasSound: isAppPreview)
        let how: String? = if isAppPreview {
            String(localized: "click the video to play or pause")
        } else if isVideo {
            String(localized: "plays muted on repeat")
        } else {
            nil
        }
        let parts = [item.pixelSize.title, status.title, how].compactMap(\.self)
        return ReviewViewerItem(
            id: PushProgressEntry.extraID(item.id), title: item.title, subtitle: parts.joined(separator: " · "), content: .file(file)
        )
    }
}
