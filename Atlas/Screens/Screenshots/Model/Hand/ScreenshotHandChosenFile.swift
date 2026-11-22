//
//  ScreenshotHandChosenFile.swift
//  Atlas
//

import Foundation
import ImageIO

/// A file picked for a set by hand, as read from disk: its name and
/// bytes, its size in pixels and whether it's a PNG or JPEG at all (nil
/// size when Atlas can't read it), and whether it has transparency.
struct ScreenshotHandChosenFile: Hashable, Sendable, Identifiable {
    var id = UUID()
    let fileName: String
    let data: Data
    let pixelSize: PixelSize?
    let hasTransparency: Bool

    init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
        let read = Self.read(data)
        pixelSize = read.size
        hasTransparency = read.isPNG && ScreenshotPNG.hasAlpha(data)
    }

    init(url: URL) {
        self.init(fileName: url.lastPathComponent, data: (try? Data(contentsOf: url)) ?? Data())
    }

    /// The image's size, and whether it's a PNG; nil size when it isn't a
    /// PNG or JPEG.
    private static func read(_ data: Data) -> (size: PixelSize?, isPNG: Bool) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == "public.png" || type == "public.jpeg",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return (nil, false) }
        return (PixelSize(width: width, height: height), type == "public.png")
    }
}
