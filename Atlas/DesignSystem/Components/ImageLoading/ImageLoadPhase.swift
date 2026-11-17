//
//  ImageLoadPhase.swift
//  Atlas
//

import CoreGraphics

/// Where an image a view downloads, reads or renders has got to, so its
/// place can say it's on its way instead of looking empty.
enum ImageLoadPhase {
    case loading
    case loaded(CGImage)
    /// Nothing came, and nothing will: no file, a failed download, or no
    /// image to show.
    case unavailable

    /// What a finished load gave.
    init(finished image: CGImage?) {
        if let image {
            self = .loaded(image)
        } else {
            self = .unavailable
        }
    }

    var image: CGImage? {
        if case let .loaded(image) = self { return image }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
