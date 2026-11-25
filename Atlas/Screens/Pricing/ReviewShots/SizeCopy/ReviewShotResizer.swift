//
//  ReviewShotResizer.swift
//  Atlas
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Makes the 640 × 920 copy of a review screenshot: the whole image fitted
/// in, never cropped, so the plan and its price still show, on the colour
/// of its top-left pixel (the paywall's own background, usually). PNG.
enum ReviewShotResizer {
    enum Failure: Error {
        case unreadable
        case unwritable
    }

    static func copy(_ data: Data, to size: PixelSize = ReviewShotSizeCopy.size) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width > 0, image.height > 0
        else { throw Failure.unreadable }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw Failure.unwritable }
        context.setFillColor(background(of: image, space: space))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.interpolationQuality = .high
        context.draw(image, in: fitted(image, in: size))
        guard let copy = context.makeImage() else { throw Failure.unwritable }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.unwritable
        }
        CGImageDestinationAddImage(destination, copy, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.unwritable }
        return output as Data
    }

    /// Where the image goes: as large as fits, centred, whole pixels.
    static func fitted(_ image: CGImage, in size: PixelSize) -> CGRect {
        let scale = min(Double(size.width) / Double(image.width), Double(size.height) / Double(image.height))
        let width = (Double(image.width) * scale).rounded()
        let height = (Double(image.height) * scale).rounded()
        return CGRect(x: ((Double(size.width) - width) / 2).rounded(), y: ((Double(size.height) - height) / 2).rounded(), width: width, height: height)
    }

    /// The image's top-left pixel, opaque.
    private static func background(of image: CGImage, space: CGColorSpace) -> CGColor {
        var pixel = [UInt8](repeating: 255, count: 4)
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ), let corner = image.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)) else { return false }
            context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return white }
        return CGColor(srgbRed: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255, alpha: 1)
    }
}
