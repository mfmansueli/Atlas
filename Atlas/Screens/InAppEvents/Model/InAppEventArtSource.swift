//
//  InAppEventArtSource.swift
//  Atlas
//

import Foundation

/// Where one of an event's images comes from: a file on this Mac (a
/// concept's still, or art waiting in Review & Push), the image on the App
/// Store, the App Store's video with its poster frame, one the App Store
/// has but gave no link to (drawn as the event's colors), or none yet.
enum InAppEventArtSource: Hashable, Sendable {
    case file(path: String, isVideo: Bool)
    case remote(URL)
    /// App Store Connect's clip, played muted on repeat over its poster
    /// frame once `RemoteVideoCache` has it on this Mac.
    case remoteVideo(poster: URL?, video: URL)
    case withoutLink
    case none

    var exists: Bool { self != .none }

    /// App Store Connect's own `media`: its clip with its poster frame, or
    /// its image; nil when Apple gave a link to neither.
    init?(remote media: InAppEventMedia) {
        if media.isVideo, let video = media.videoURL {
            self = .remoteVideo(poster: media.imageURL, video: video)
        } else if let image = media.imageURL {
            self = .remote(image)
        } else {
            return nil
        }
    }

    init(_ image: EventArtworkImage?) {
        if let image { self = .file(path: image.path, isVideo: image.isVideo) } else { self = .none }
    }
}
