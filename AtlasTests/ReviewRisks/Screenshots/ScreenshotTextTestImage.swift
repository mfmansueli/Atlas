//
//  ScreenshotTextTestImage.swift
//  AtlasTests
//

import CoreGraphics
import CoreText
import Foundation
@testable import Atlas

/// Images with text drawn in them for the Vision tests: black lines on
/// white, without alpha, at an App Store iPhone size.
enum ScreenshotTextTestImage {
    static let size = PixelSize(width: 1320, height: 2868)

    /// `lines` drawn large from the top, one under the other.
    static func image(_ lines: [String], size: PixelSize = size, pointSize: CGFloat = 120) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, pointSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ]
        for (index, text) in lines.enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            // Core Graphics counts from the bottom.
            context.textPosition = CGPoint(x: 100, y: CGFloat(size.height) - 400 - CGFloat(index) * pointSize * 1.6)
            CTLineDraw(line, context)
        }
        return context.makeImage()
    }

    /// The same as a PNG.
    static func png(_ lines: [String], size: PixelSize = size) -> Data? {
        image(lines, size: size).flatMap(ScreenshotPNG.data)
    }
}
