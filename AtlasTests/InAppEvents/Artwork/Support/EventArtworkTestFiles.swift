//
//  EventArtworkTestFiles.swift
//  AtlasTests
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Atlas

/// Event cards and details pages made on the spot: flat or busy images
/// as PNG or JPEG, with or without alpha, and short H.264 videos at any
/// size and frame rate, in a folder of their own.
enum EventArtworkTestFiles {
    /// A new empty folder for one test's files.
    static func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "EventArtworkTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A calm image: a dark blue top fading to a darker bottom. `busy`
    /// draws a fine checkerboard over the lower half.
    static func image(width: Int, height: Int, busy: Bool = false, alpha: Bool = false) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0.12, green: 0.18, blue: 0.36, alpha: alpha ? 0.6 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if busy {
            let cell = max(2, width / 160)
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            for y in stride(from: 0, to: height / 2, by: cell) {
                for x in stride(from: (y / cell) % 2 * cell, to: width, by: cell * 2) {
                    context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }
        return context.makeImage()
    }

    static func png(width: Int, height: Int, busy: Bool = false, alpha: Bool = false) -> Data {
        image(width: width, height: height, busy: busy, alpha: alpha).flatMap(ScreenshotPNG.data) ?? Data()
    }

    static func jpeg(width: Int, height: Int) -> Data {
        guard let image = image(width: width, height: height) else { return Data() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : Data()
    }

    /// Keeps `data` as `name` for `appID` and returns its file ID.
    static func store(_ data: Data, name: String, appID: String = InAppEventsTestData.app.id, in directory: URL) throws -> String {
        try InAppEventArtworkFiles.save(data, fileName: name, appID: appID, in: directory)
    }

    /// A silent H.264 video of `frames` flat frames at `fps`.
    static func movie(width: Int, height: Int, fps: Int32, frames: Int = 12, in directory: URL, name: String = "loop.mov") async throws -> URL {
        let url = directory.appending(path: name)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: name.hasSuffix(".mp4") ? .mp4 : .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            guard let pool = adaptor.pixelBufferPool else { throw CocoaError(.fileWriteUnknown) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw CocoaError(.fileWriteUnknown) }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(40 + frame), CVPixelBufferGetDataSize(buffer))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    /// A movie kept for `appID`, as the upload link keeps one.
    static func storedMovie(width: Int, height: Int, fps: Int32, frames: Int = 12, in directory: URL) async throws -> String {
        let scratch = Self.directory()
        let url = try await movie(width: width, height: height, fps: fps, frames: frames, in: scratch)
        return try store(Data(contentsOf: url), name: "loop.mov", in: directory)
    }
}
