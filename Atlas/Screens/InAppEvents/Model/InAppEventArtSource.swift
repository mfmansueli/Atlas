//
//  InAppEventArtSource.swift
//  Atlas
//

import Foundation

/// Where one of an event's images comes from: a file on this Mac (a
/// concept's still, or art waiting in Review & Push), the image on the App
/// Store, one the App Store has but gave no link to (drawn as the event's
/// colors), or none yet.
enum InAppEventArtSource: Hashable, Sendable {
    case file(path: String, isVideo: Bool)
    case remote(URL)
    case withoutLink
    case none

    var exists: Bool { self != .none }

    init(_ image: EventArtworkImage?) {
        if let image { self = .file(path: image.path, isVideo: image.isVideo) } else { self = .none }
    }
}
