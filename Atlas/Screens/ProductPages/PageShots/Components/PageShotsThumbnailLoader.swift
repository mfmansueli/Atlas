//
//  PageShotsThumbnailLoader.swift
//  Atlas
//

import CoreGraphics
import Foundation
import ImageIO

/// Small images of the screenshots a page's set was laid out as, read
/// from their PNGs off the main thread and kept while Atlas runs.
@MainActor
enum PageShotsThumbnailLoader {
    private static let cache = NSCache<NSString, CGImage>()

    static func image(at url: URL, maxPixel: Int) async -> CGImage? {
        let key = "\(url.path)|\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    /// Forgets a run's images: they were laid out again.
    static func forget() {
        cache.removeAllObjects()
    }
}
