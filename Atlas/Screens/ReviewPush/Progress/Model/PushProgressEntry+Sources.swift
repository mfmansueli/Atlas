//
//  PushProgressEntry+Sources.swift
//  Atlas
//

import Foundation

/// The rows of the three pushes Review & Push shows as one: changes (an
/// event's art among them), screenshots, and the header, search images and
/// App Previews.
extension PushProgressEntry {
    /// A change; `artwork` is the event art it uploads, if it's one.
    init(item: PushItem, artwork: InAppEventArtworkPush?) {
        let kind: PushProgressKind = if let artwork { artwork.isVideo ? .video : .image } else { .change }
        self.init(
            id: Self.changeID(item.id), title: "\(item.change.title) · \(item.change.group)", kind: kind, state: PushProgressState(item.status)
        )
    }

    init(upload: ScreenshotUploadItem) {
        self.init(id: Self.shotID(upload.id), title: upload.title, kind: .image, state: PushProgressState(upload.status))
    }

    init(extra: ExtrasPushItem, status: ExtrasPushStatus) {
        self.init(
            id: Self.extraID(extra.id), title: extra.title, kind: extra.kind.media == .video ? .video : .image, state: PushProgressState(status)
        )
    }

    static func changeID(_ id: PendingChange.ID) -> String { "change.\(id)" }
    static func shotID(_ id: ScreenshotUploadItem.ID) -> String { "shot.\(id)" }
    static func extraID(_ id: ExtrasPushItem.ID) -> String { "extra.\(id)" }
}
