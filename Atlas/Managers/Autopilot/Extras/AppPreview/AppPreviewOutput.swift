//
//  AppPreviewOutput.swift
//  Atlas
//

import Foundation

/// The App Preview file Atlas wrote.
struct AppPreviewOutput: Hashable, Sendable {
    var url: URL
    var seconds: Double
    var pixelSize: PixelSize
    var byteCount: Int64
}
