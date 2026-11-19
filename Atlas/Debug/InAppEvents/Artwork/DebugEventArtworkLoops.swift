//
//  DebugEventArtworkLoops.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// Real movies for the `ea-motion` scene, so the full-size viewer has a
/// loop to play: each still, small, with a warm light drifting across it,
/// 4 seconds at 30 fps. Written next to the stills in a second or so.
enum DebugEventArtworkLoops {
    static let framesPerSecond = 30
    static let frameCount = 120

    /// A loop for each still, as the concept's moving versions; a still
    /// whose movie can't be written gets none.
    static func write(for stills: [EventArtworkImage]) async -> [EventArtworkImage] {
        var videos: [EventArtworkImage] = []
        for still in stills {
            let source = URL(filePath: still.path)
            let output = source.deletingPathExtension().appendingPathExtension("mov")
            guard let image = load(source) else { continue }
            let size = still.kind == .card ? PixelSize(width: 640, height: 360) : PixelSize(width: 360, height: 640)
            do {
                let writer = try ArtworkLoopWriter(output: output, size: size, framesPerSecond: framesPerSecond)
                for frame in 0..<frameCount {
                    let progress = Double(frame) / Double(frameCount)
                    try await writer.appendFrame { context in
                        draw(image, in: CGRect(origin: .zero, size: size.cgSize), progress: progress, context: context)
                    }
                }
                try await writer.finish()
                videos.append(EventArtworkImage(kind: still.kind, fileID: still.fileID, path: output.path(percentEncoded: false), isVideo: true))
            } catch {
                continue
            }
        }
        return videos
    }

    /// The still, and the light along an arc in the upper part.
    private static func draw(_ image: CGImage, in rect: CGRect, progress: Double, context: CGContext) {
        context.draw(image, in: rect)
        let radius = min(rect.width, rect.height) * 0.07
        let x = rect.width * (0.1 + 0.8 * progress)
        let y = rect.height * (0.72 + 0.08 * sin(progress * 2 * .pi))
        context.setFillColor(CGColor(srgbRed: 1, green: 0.88, blue: 0.6, alpha: 0.9))
        context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    private static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
#endif
