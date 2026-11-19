//
//  RenderEventArtworkTool+MotionFrames.swift
//  Atlas
//

import CoreGraphics
import Foundation

@MainActor
extension RenderEventArtworkTool {
    /// The moments of the loop `motionFrames` shows: off the beat of every
    /// duration that divides 20 seconds (1, 2, 2.5, 4, 5, 10), so a short
    /// repeating motion never looks still in them.
    static let motionFrameSeconds: [Double] = [0, 2.75, 7.25, 13.75]

    /// "0, 2.75, 7.25 and 13.75 seconds".
    static var motionFrameMoments: String {
        let moments = motionFrameSeconds.map { $0.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US"))) }
        return "\(moments.formatted(.list(type: .and).locale(Locale(identifier: "en_US")))) seconds"
    }

    /// The share of the canvas the frames are drawn at: the video's size.
    static let motionDrawingScale = 0.5

    /// Below this, frames count as the same picture (`ArtworkLoopChecker`'s
    /// mean difference per channel, 0–255).
    static let stillTolerance = 0.5

    /// A page's loop at a few moments, and whether it repeats evenly, without
    /// encoding the video: seconds instead of a minute, so Claude can
    /// look at the motion before sending a concept.
    func motionFrames(_ page: EventArtworkPage) async throws -> (json: JSONValue, images: [MCPToolOutcome.ImageContent]) {
        let loop = Double(AutopilotArtworkMotion.loopSeconds)
        let width = page.kind == .card ? 960 : 540
        // Drawn at half the canvas, as the video is: the frames are smaller
        // still, and a heavy page at full size can end WebKit's process.
        var request = page.request
        request.drawingScale = Self.motionDrawingScale
        let (frames, measure) = try await ArtworkWebRenderer.shared.withLoadedPage(request) { webPage, measure in
            var frames: [CGImage] = []
            for second in Self.motionFrameSeconds + [loop] {
                try await frames.append(webPage.frame(at: second, width: width))
            }
            return (frames, measure)
        }
        guard let first = frames.first, let end = frames.last else { return (["moves": false], []) }
        let jumps = measure.motionsThatMayJump(loopSeconds: loop)
        let seam = ArtworkLoopChecker.difference(first, end) ?? 0
        let moments = frames.dropFirst().dropLast()
        let change = moments.compactMap { ArtworkLoopChecker.difference(first, $0) }.max() ?? 0
        let upper = moments.compactMap { Self.difference(first, $0, part: .upper) }.max() ?? 0
        let lower = moments.compactMap { Self.difference(first, $0, part: .lower) }.max() ?? 0
        var notes: [String] = []
        if !measure.moves || change < Self.stillTolerance {
            notes.append("Nothing visibly moves: give the page CSS or SVG animation, as motionDirection says.")
        }
        if !jumps.isEmpty {
            notes.append("""
            \(jumps.count) animation(s) don't repeat a whole number of times in \(AutopilotArtworkMotion.loopSeconds) s, so the \
            loop jumps when it starts again: use durations that divide \(AutopilotArtworkMotion.loopSeconds) s.
            """)
        }
        if seam > ArtworkLoopChecker.seamTolerance {
            notes.append("The frame at \(AutopilotArtworkMotion.loopSeconds) s doesn't match the one at 0 s, so the loop jumps.")
        }
        if lower > Self.stillTolerance * 4, lower > upper {
            notes.append("More moves in the lower part, under Apple's text, than above it: calm it and let the subject move.")
        }
        let json: JSONValue = [
            "frames": .string("attached after the art: the loop at \(Self.motionFrameMoments)"),
            "moves": .bool(measure.moves && change >= Self.stillTolerance),
            "repeatsEvenly": .bool(jumps.isEmpty),
            "endMeetsStart": .bool(seam <= ArtworkLoopChecker.seamTolerance),
            "notes": .array(notes.map(JSONValue.string)),
        ]
        let images = frames.dropLast()
            .compactMap { InAppEventArtworkInspector.jpeg($0, maxPixel: width) }
            .map { MCPToolOutcome.ImageContent(data: $0, mimeType: "image/jpeg") }
        return (json, images)
    }

    enum FramePart { case upper, lower }

    /// The change between two frames in the part above Apple's text, or in
    /// the lower part under it.
    static func difference(_ lhs: CGImage, _ rhs: CGImage, part: FramePart) -> Double? {
        let split = InAppEventArtworkLook.lowerPart
        func crop(_ image: CGImage) -> CGImage? {
            let height = Double(image.height)
            let top = (height * split).rounded()
            let rect = part == .upper
                ? CGRect(x: 0, y: 0, width: Double(image.width), height: top)
                : CGRect(x: 0, y: top, width: Double(image.width), height: height - top)
            return image.cropping(to: rect)
        }
        guard let left = crop(lhs), let right = crop(rhs) else { return nil }
        return ArtworkLoopChecker.difference(left, right)
    }
}
