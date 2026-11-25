//
//  AppStoreEventArt.swift
//  Atlas
//

import Foundation

/// What the App Store preview's event card shows: the file Atlas uploaded
/// the card from when it's still on this Mac (a video then plays muted on
/// repeat, as on the App Store, through `AutoplayingLoop`), else App Store
/// Connect's own (a video streams through `RemoteVideoCache` over its
/// poster frame), else the event's gradient.
enum AppStoreEventArt {
    /// App Store Connect's image or video of `card`.
    static func poster(of card: InAppEventMedia?) -> InAppEventArtSource {
        card.flatMap(InAppEventArtSource.init(remote:)) ?? .none
    }

    /// The file `card` was uploaded from, among `stored` (Apple keeps the
    /// name and size Atlas sent), else App Store Connect's.
    static func source(for card: InAppEventMedia?, stored: [InAppEventArtworkStoredFile]) -> InAppEventArtSource {
        guard let card, let file = InAppEventArtworkStoredFile.matching(fileName: card.fileName, fileSize: card.fileSize, in: stored).first else {
            return poster(of: card)
        }
        return .file(path: file.path, isVideo: card.isVideo)
    }

    /// `source(for:stored:)` with the files kept for `event`'s app, read
    /// off the main thread.
    static func source(for event: AppStoreLiveEvent, directory: URL = InAppEventArtworkFiles.directory) async -> InAppEventArtSource {
        guard let appID = event.appID, event.card?.fileName != nil else { return poster(of: event.card) }
        let stored = await Task.detached(priority: .userInitiated) {
            InAppEventArtworkFiles.stored(appID: appID, in: directory)
        }.value
        return source(for: event.card, stored: stored)
    }
}
