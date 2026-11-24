//
//  ScreenshotsServices+KeptLiveImage.swift
//  Atlas
//

import CoreGraphics

// Services that keep no decoded images (DEBUG scenes, tests) always load.
extension ScreenshotsServices {
    func keptLiveImage(_: LiveScreenshot, pixelWidth _: Int) -> CGImage? { nil }
}
