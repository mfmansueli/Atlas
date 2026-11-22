//
//  ScreenshotsHandDebugFiles.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation

/// Files for the Screenshots by hand scenes: opaque PNGs of a size, in a
/// color, named like what a person would drop.
enum ScreenshotsHandDebugFiles {
    static func png(_ size: PixelSize, red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return Data() }
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.85)
        let inset = CGFloat(size.width) * 0.12
        context.fill(CGRect(x: inset, y: inset * 2, width: CGFloat(size.width) - inset * 2, height: CGFloat(size.height) * 0.55))
        guard let image = context.makeImage() else { return Data() }
        return ScreenshotPNG.data(image) ?? Data()
    }

    /// A file that fits iPhone 6.9″.
    static func fitting(_ name: String, hue: Int = 0) -> ScreenshotHandChosenFile {
        let colors: [(CGFloat, CGFloat, CGFloat)] = [(0.89, 0.33, 0.24), (0.18, 0.56, 0.48), (0.35, 0.28, 0.84), (0.85, 0.6, 0)]
        let color = colors[hue % colors.count]
        return ScreenshotHandChosenFile(
            fileName: name, data: png(PixelSize(width: 1320, height: 2868), red: color.0, green: color.1, blue: color.2)
        )
    }

    /// An iPhone 15 Pro screenshot: not a size the set takes.
    static func wrongSize(_ name: String = "Screenshot 2026-11-20 at 18.04.png") -> ScreenshotHandChosenFile {
        ScreenshotHandChosenFile(fileName: name, data: png(PixelSize(width: 1179, height: 2556), red: 0.4, green: 0.4, blue: 0.45))
    }
}
#endif
