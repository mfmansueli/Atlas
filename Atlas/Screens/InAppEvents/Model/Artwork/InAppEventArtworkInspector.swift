//
//  InAppEventArtworkInspector.swift
//  Atlas
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reads an event card or details page file: an image's size, color model
/// and alpha with ImageIO, a video's size, frame rate, length, codec and
/// audio with AVFoundation, and the still the checks look at (the image,
/// or the video's poster frame).
enum InAppEventArtworkInspector {
    /// What `url` is; nil when it's neither an image nor a video
    /// Atlas can read.
    static func inspect(_ url: URL, fileName: String? = nil) async -> InAppEventArtworkFile? {
        let name = fileName ?? url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let extensionName = URL(fileURLWithPath: name).pathExtension.lowercased()
        if InAppEventArtworkRules.videoExtensions.contains(extensionName) || !isImage(url) {
            return await video(url, fileName: name, fileSize: size)
        }
        return image(url, fileName: name, fileSize: size)
    }

    /// The image itself, or a video's frame at `seconds`.
    static func still(_ url: URL, isVideo: Bool, at seconds: Double = 0) async -> CGImage? {
        guard isVideo else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        return try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }

    /// A small still of the file, `maxPixel` on its longer side.
    static func thumbnail(_ url: URL, isVideo: Bool, maxPixel: Int) async -> CGImage? {
        guard isVideo else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        return try? await generator.image(at: .zero).image
    }

    /// A JPEG of `image` at most `maxPixel` on its longer side, for what
    /// the tools show the assistant.
    static func jpeg(_ image: CGImage, maxPixel: Int) -> Data? {
        let scale = min(1, Double(maxPixel) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, scaled, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceGetCount(source) > 0 && CGImageSourceGetType(source) != nil
            && CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil
    }

    private static func image(_ url: URL, fileName: String, fileSize: Int) -> InAppEventArtworkFile? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        // EXIF orientations 5–8 are turned a quarter.
        let size = orientation >= 5 ? PixelSize(width: height, height: width) : PixelSize(width: width, height: height)
        return InAppEventArtworkFile(
            fileName: fileName, fileSize: fileSize, isVideo: false, pixelSize: size,
            hasAlpha: properties[kCGImagePropertyHasAlpha] as? Bool ?? false,
            colorModel: properties[kCGImagePropertyColorModel] as? String
        )
    }

    private static func video(_ url: URL, fileName: String, fileSize: Int) async -> InAppEventArtworkFile? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform, frameRate, descriptions) = try? await track.load(
                  .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions
              )
        else { return nil }
        let shown = natural.applying(transform)
        let duration = await (try? asset.load(.duration)).map(CMTimeGetSeconds)
        var file = InAppEventArtworkFile(
            fileName: fileName, fileSize: fileSize, isVideo: true,
            pixelSize: PixelSize(width: Int(abs(shown.width).rounded()), height: Int(abs(shown.height).rounded())),
            frameRate: Double(frameRate), seconds: duration.flatMap { $0.isFinite ? $0 : nil },
            codec: descriptions.first.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) }
        )
        for audioTrack in await (try? asset.loadTracks(withMediaType: .audio)) ?? [] {
            guard let description = try? await audioTrack.load(.formatDescriptions).first,
                  let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee
            else { continue }
            file.audio.append(InAppEventArtworkFile.Audio(
                format: audioFormat(basic.mFormatID), channels: Int(basic.mChannelsPerFrame), sampleRate: basic.mSampleRate
            ))
        }
        return file
    }

    private static func audioFormat(_ id: AudioFormatID) -> String {
        switch id {
        case kAudioFormatMPEG4AAC: "aac"
        case kAudioFormatLinearPCM: "lpcm"
        default: fourCC(id)
        }
    }

    /// "avc1" for `'avc1'`.
    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? String(code)
    }
}
