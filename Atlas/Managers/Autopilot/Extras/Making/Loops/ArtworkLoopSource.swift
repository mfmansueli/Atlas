//
//  ArtworkLoopSource.swift
//  Atlas
//

import Foundation

/// What a loop is drawn from: Atlas's own layout, its still layers
/// ready (`ArtworkLoopLayers`), or an HTML page, stepped frame by
/// frame (`ArtworkWebLoop`).
enum ArtworkLoopSource: Sendable {
    case layers(ArtworkLoopLayers, layout: ArtworkLayout)
    case page(ArtworkWebRequest)
}
