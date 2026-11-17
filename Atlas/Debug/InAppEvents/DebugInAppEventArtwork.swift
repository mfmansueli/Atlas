//
//  DebugInAppEventArtwork.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation

/// Art Claude Code proposed for the Winter Reflection Challenge, for the
/// `ev-art` scene: a card for every language and an English details page,
/// drawn on the spot into a temporary folder, waiting to be accepted.
enum DebugInAppEventArtwork {
    static let directory = FileManager.default.temporaryDirectory.appending(path: "AtlasDebugEventArt", directoryHint: .isDirectory)

    @MainActor
    static func changes() -> [PendingChange] {
        let event = DebugInAppEventsData.winter
        let builder = InAppEventChangeBuilder(appID: DebugFixtures.AppID.lumen)
        let source = ChangeSource.assistant(client: DebugInAppEventsData.client)
        var changes: [PendingChange] = []
        if let card = report(.card, width: 1920, height: 1080, name: "winter-card.png") {
            changes += event.localizations.map { builder.artworkChange(card, into: $0, of: event, source: source) }
        }
        if let details = report(.details, width: 1080, height: 1920, name: "winter-details.png"), let english = event.localization("en-US") {
            changes.append(builder.artworkChange(details, into: english, of: event, source: source))
        }
        return changes
    }

    /// A night-blue gradient with a pale moon, as a checked file.
    private static func report(_ kind: InAppEventMedia.Kind, width: Int, height: Int, name: String) -> InAppEventArtworkReport? {
        guard let image = draw(width: width, height: height), let png = ScreenshotPNG.data(image) else { return nil }
        let url = directory.appending(path: name)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? png.write(to: url, options: .atomic)) != nil else { return nil }
        let file = InAppEventArtworkFile(
            fileName: name, fileSize: png.count, isVideo: false, pixelSize: PixelSize(width: width, height: height), colorModel: "RGB"
        )
        return InAppEventArtworkReport(
            fileID: "ea-debug", url: url, kind: kind, file: file, still: image, posterSeconds: 0, look: nil,
            checks: InAppEventArtworkChecker.checks(file, kind: kind, look: nil)
        )
    }

    private static func draw(width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ),
              let gradient = CGGradient(colorsSpace: space, colors: [
                  CGColor(srgbRed: 0.09, green: 0.13, blue: 0.3, alpha: 1), CGColor(srgbRed: 0.36, green: 0.42, blue: 0.72, alpha: 1),
              ] as CFArray, locations: [0, 1])
        else { return nil }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        let radius = Double(min(width, height)) * 0.12
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.95, blue: 0.86, alpha: 1))
        context.fillEllipse(in: CGRect(x: Double(width) * 0.68, y: Double(height) * 0.62, width: radius * 2, height: radius * 2))
        return context.makeImage()
    }
}
#endif
