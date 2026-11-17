//
//  ArtworkLoopSource.swift
//  Atlas
//

import Foundation

/// What a loop is drawn from: Atlas's own layout, its still layers
/// ready (`ArtworkLoopLayers`), or a Claude Design page, stepped frame by
/// frame (`ArtworkWebLoop`).
enum ArtworkLoopSource: Sendable {
    case layers(ArtworkLoopLayers, layout: ArtworkLayout)
    case page(ArtworkWebRequest)
}
