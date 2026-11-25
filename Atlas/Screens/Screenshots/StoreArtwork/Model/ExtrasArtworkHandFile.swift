//
//  ExtrasArtworkHandFile.swift
//  Atlas
//

import Foundation

/// A header or search image the person gave by hand (Add Header…,
/// Replace…), not made by Autopilot: its file's name and size.
struct ExtrasArtworkHandFile: Codable, Hashable, Sendable {
    var fileName: String
    var pixelSize: PixelSize
    var addedAt: Date
}
