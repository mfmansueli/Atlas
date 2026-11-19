//
//  ReviewViewerFile.swift
//  Atlas
//

import Foundation

/// A file the push progress opens large: an image read from it, or a
/// movie (an App Preview, a motion loop, an event video) that plays muted
/// on repeat. `pixelSize` sets its proportions before it's read.
struct ReviewViewerFile: Hashable, Sendable {
    var url: URL
    var isVideo: Bool
    var pixelSize: PixelSize
}
