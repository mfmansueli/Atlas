//
//  ProductPageChosenFile.swift
//  Atlas
//

import Foundation

/// One image picked with Choose Files… for a page's own screenshots, as
/// read from disk: its name, its bytes and its size in pixels (nil when it
/// isn't an image Atlas can read).
struct ProductPageChosenFile: Hashable, Sendable {
    let fileName: String
    let data: Data
    let pixelSize: PixelSize?
}
