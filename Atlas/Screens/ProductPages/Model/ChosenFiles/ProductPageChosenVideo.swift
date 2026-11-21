//
//  ProductPageChosenVideo.swift
//  Atlas
//

import Foundation

/// One video picked with Choose App Previews… for a page, as read from
/// disk: its name, its bytes, its size in pixels as it plays (turned by its
/// transform) and its length; nil when Atlas can't read them.
struct ProductPageChosenVideo: Hashable, Sendable {
    let fileName: String
    let data: Data
    let pixelSize: PixelSize?
    let seconds: Double?
}
