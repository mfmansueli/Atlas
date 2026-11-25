//
//  ScreenshotsServices+LivePreview.swift
//  Atlas
//

import CoreGraphics

// Services that read nothing beyond the sets (tests, most DEBUG scenes)
// show an App Preview without its poster frame or length.
extension ScreenshotsServices {
    func livePreviewPoster(_: LiveAppPreview, pixelWidth _: Int) async -> CGImage? { nil }

    func livePreviewSeconds(_: LiveAppPreview) async -> Int? { nil }
}
