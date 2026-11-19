//
//  DebugEventArtworkConcepts.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// Claude's three concepts for the Winter Reflection Challenge, for
/// the `ea-*` scenes and tests: each a card and a details image drawn on the
/// spot into a temporary folder, checked like real ones. "Snowfall Path"
/// is the pick; "Quiet Lantern" has a light lower part, "Aurora Pages" a
/// busy one, so their checks warn.
@MainActor
enum DebugEventArtworkConcepts {
    static let directory = FileManager.default.temporaryDirectory.appending(path: "AtlasDebugEventArtStudio", directoryHint: .isDirectory)
    static let appID = DebugFixtures.AppID.lumen
    static let client = DebugInAppEventsData.client

    enum Motif {
        case path
        case lantern
        case aurora
    }

    struct Palette {
        var top: (Double, Double, Double)
        var bottom: (Double, Double, Double)
        var motif: Motif
    }

    static let snowfall = Palette(top: (0.05, 0.09, 0.24), bottom: (0.16, 0.25, 0.5), motif: .path)
    /// Pale enough low down (luminance ≈ 0.7 over the lower part) to pass
    /// `InAppEventArtworkLook.brightLimit`.
    static let lantern = Palette(top: (0.6, 0.38, 0.2), bottom: (1.0, 0.97, 0.9), motif: .lantern)
    static let aurora = Palette(top: (0.03, 0.12, 0.16), bottom: (0.12, 0.28, 0.3), motif: .aurora)

    private static var made: [EventArtworkConcept]?

    private enum Why {
        static let snowfall = "A lit path climbs through falling snow, a step for each day of December: it reads at card size and keeps the lower third calm."
        static let lantern = "One warm lantern in the dusk, for the evenings you write in. Light and simple, but the lower part is pale."
        static let aurora = "Northern lights folding like pages over the hills. Rich, but busy where the App Store writes."
    }

    /// The three concepts, drawn once per launch.
    static func all() -> [EventArtworkConcept] {
        if let made { return made }
        let concepts = [
            concept("a", "Snowfall Path", Why.snowfall, snowfall, isPick: true),
            concept("b", "Quiet Lantern", Why.lantern, lantern),
            concept("c", "Aurora Pages", Why.aurora, aurora),
        ].compactMap(\.self)
        made = concepts
        return concepts
    }

    /// The run the scenes start from: Claude's, at `step`.
    static func run(step: EventArtworkStep, ready: Int = 3, isHidden: Bool = false) -> EventArtworkRun {
        let event = DebugInAppEventsData.winter
        var run = EventArtworkRun(
            appID: appID, eventID: event.id, eventName: event.referenceName, brief: EventArtworkBrief.written(for: event),
            style: .newLook, locales: EventArtworkFlow.locales(of: event)
        )
        run.step = step
        run.concepts = Array(all().prefix(ready))
        run.pickedID = run.concepts.first?.id
        run.isHidden = isHidden
        run.startedAt = DebugReviewsData.today.addingTimeInterval(-120)
        return run
    }

    /// Use This Artwork's changes for concept `a`, for `ea-used`.
    static func usedChanges() -> [PendingChange] {
        let event = DebugInAppEventsData.winter
        guard let concept = all().first else { return [] }
        let builder = InAppEventChangeBuilder(appID: appID)
        var changes: [PendingChange] = []
        for kind in concept.kinds {
            guard let still = concept.still(kind), let report = report(still) else { continue }
            for localization in event.localizations {
                var change = builder.artworkChange(report, into: localization, of: event, source: .assistant(client: client))
                change.awaitingAcceptance = nil
                changes.append(change)
            }
        }
        return changes
    }

    private static func concept(_ id: String, _ name: String, _ why: String, _ palette: Palette, isPick: Bool = false) -> EventArtworkConcept? {
        var stills: [EventArtworkImage] = []
        var reports: [InAppEventArtworkReport] = []
        for kind in InAppEventMedia.Kind.allCases {
            let size = InAppEventArtworkRules.minimumSize(for: kind)
            let fileName = "\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(kind.mcpValue).png"
            guard let image = draw(palette, width: size.width, height: size.height), let png = ScreenshotPNG.data(image),
                  let fileID = try? InAppEventArtworkFiles.save(png, fileName: fileName, appID: appID, in: directory),
                  let url = InAppEventArtworkFiles.url(id: fileID, appID: appID, in: directory)
            else { return nil }
            let still = EventArtworkImage(kind: kind, fileID: fileID, path: url.path(percentEncoded: false))
            stills.append(still)
            if let report = report(still, image: image) { reports.append(report) }
        }
        return EventArtworkConcept(
            id: id, name: name, why: why, isPick: isPick, client: client, stills: stills,
            checks: EventArtworkConceptChecks.make(reports, wordsInArt: false), arrivedAt: DebugReviewsData.today
        )
    }

    /// A checked file, read without Vision so scenes stay quick.
    static func report(_ still: EventArtworkImage, image: CGImage? = nil) -> InAppEventArtworkReport? {
        let url = URL(filePath: still.path)
        guard let image = image ?? load(url), let data = try? Data(contentsOf: url) else { return nil }
        let file = InAppEventArtworkFile(
            fileName: url.lastPathComponent, fileSize: data.count, isVideo: false, pixelSize: PixelSize(width: image.width, height: image.height),
            colorModel: "RGB"
        )
        let look = InAppEventArtworkLook(
            text: [], lowerBusyness: InAppEventArtworkLook.busyness(of: image), lowerBrightness: InAppEventArtworkLook.brightness(of: image)
        )
        return InAppEventArtworkReport(
            fileID: still.fileID, url: url, kind: still.kind, file: file, still: image, posterSeconds: 0, look: look,
            checks: InAppEventArtworkChecker.checks(file, kind: still.kind, look: look)
        )
    }

    private static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func color(_ rgb: (Double, Double, Double), alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: alpha)
    }

    /// The palette's sky (CoreGraphics draws from the bottom up), and its
    /// motif in the upper part.
    private static func draw(_ palette: Palette, width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ),
              let gradient = CGGradient(colorsSpace: space, colors: [color(palette.bottom), color(palette.top)] as CFArray, locations: [0, 1])
        else { return nil }
        let wide = Double(width)
        let high = Double(height)
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: high), options: [])
        let unit = min(wide, high)
        switch palette.motif {
        case .path:
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85))
            for index in 0..<60 {
                let x = Double((index * 97) % 100) / 100 * wide
                let y = high * 0.5 + Double((index * 61) % 50) / 100 * high
                context.fillEllipse(in: CGRect(x: x, y: y, width: unit * 0.008, height: unit * 0.008))
            }
            context.setFillColor(CGColor(srgbRed: 1, green: 0.86, blue: 0.55, alpha: 1))
            for step in 0..<7 {
                let x = wide * (0.15 + 0.1 * Double(step))
                let y = high * (0.45 + 0.05 * Double(step))
                context.fill(CGRect(x: x, y: y, width: unit * 0.06, height: unit * 0.015))
            }
        case .lantern:
            context.setFillColor(CGColor(srgbRed: 1, green: 0.93, blue: 0.7, alpha: 1))
            context.fillEllipse(in: CGRect(x: wide * 0.5 - unit * 0.1, y: high * 0.62, width: unit * 0.2, height: unit * 0.2))
        case .aurora:
            for band in 0..<5 {
                context.setFillColor(CGColor(srgbRed: 0.3, green: 0.9 - 0.1 * Double(band), blue: 0.6 + 0.08 * Double(band), alpha: 0.35))
                context.fill(CGRect(x: 0, y: high * (0.62 + 0.06 * Double(band)), width: wide, height: high * 0.03))
            }
            // Fine stripes low down: the busy part the check warns about.
            context.setFillColor(CGColor(srgbRed: 0.85, green: 0.95, blue: 0.9, alpha: 0.9))
            var x = 0.0
            while x < wide {
                context.fill(CGRect(x: x, y: 0, width: 3, height: high * 0.35))
                x += 9
            }
        }
        return context.makeImage()
    }
}
#endif
