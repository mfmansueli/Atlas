//
//  ProductPageVideoCheck.swift
//  Atlas
//

import Foundation

/// Choose App Previews…' check: a set takes 1 to 3 videos, each the exact
/// size App Store Connect takes for the device (iPhone 6.9″ 886 × 1920,
/// iPad 13″ 1200 × 1600, upright or turned), 15 to 30 seconds long and at
/// most 500 MB. Every problem is said at once, each with its fix.
enum ProductPageVideoCheck {
    /// A little over or under is the container rounding, not the video.
    private static let tolerance = 0.05

    static func problems(_ videos: [ProductPageChosenVideo], device: ProductPageDevice) -> [String] {
        var problems: [String] = []
        let limit = ProductPageMedia.appPreviews.limit
        if videos.count > limit {
            problems.append(String(localized: "A set has up to 3 App Previews, and \(videos.count) were chosen. Choose 3 or fewer."))
        }
        guard let spec = AppPreviewSpec.spec(for: device.displayType, landscape: false) else { return problems }
        let size = "\(spec.pixelSize.width) × \(spec.pixelSize.height)"
        for video in videos {
            guard let pixels = video.pixelSize, let seconds = video.seconds else {
                problems.append(String(localized: "“\(video.fileName)” isn’t a MOV, MP4 or M4V video Atlas can read."))
                continue
            }
            if pixels != spec.pixelSize, pixels != spec.pixelSize.rotated {
                // Pixels are never grouped ("1080", not "1.080").
                let shown = "\(pixels.width) × \(pixels.height)"
                problems.append(String(
                    localized: "“\(video.fileName)” is \(shown). \(device.displayType.title) takes \(size), upright or turned."
                ))
            }
            if seconds < spec.minimumSeconds - tolerance || seconds > spec.maximumSeconds + tolerance {
                let shown = seconds.formatted(.number.precision(.fractionLength(0...1)))
                problems.append(String(localized: "“\(video.fileName)” is \(shown) seconds long. An App Preview is 15 to 30 seconds."))
            }
            if Int64(video.data.count) > spec.maximumBytes {
                problems.append(String(localized: "“\(video.fileName)” is over 500 MB, the most App Store Connect takes."))
            }
        }
        return problems
    }
}
