//
//  DebugStoreArtwork.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import CoreText
import Foundation

/// Board 78's sample: Lumen's headers live in English (U.S.), German,
/// Japanese and Arabic, its search artwork in English (U.S.), Japanese and
/// Arabic; French has neither. Each is drawn as a gradient with Lumen's
/// headline, in a colour of its language.
enum DebugStoreArtwork {
    static let headerLocales = ["en-US", "de-DE", "ja", "ar-SA"]
    static let searchLocales = ["en-US", "ja", "ar-SA"]

    static var live: LiveStoreArtworkSet {
        var set = LiveStoreArtworkSet()
        for locale in Set(headerLocales + searchLocales) {
            set.byLocale[locale] = LiveStoreArtwork(
                header: headerLocales.contains(locale) ? image(.header, locale: locale) : nil,
                search: searchLocales.contains(locale) ? image(.search, locale: locale) : nil
            )
        }
        return set
    }

    static func image(_ place: StoreArtworkPlace, locale: String) -> LiveArtworkImage {
        LiveArtworkImage(
            placementID: "debug-\(place.rawValue)-\(locale)", placementType: place.placementType, placementGroup: "IPHONE",
            templateURL: "atlas-debug://artwork/\(place.rawValue)/\(locale)/{w}x{h}.{f}", pixelSize: place.kind.pixelSize
        )
    }

    /// The headline each language's artwork shows.
    static func headline(_ locale: String) -> String {
        switch locale {
        case "de-DE": "Dein Tag, in Ruhe"
        case "ja": "静かな一日を"
        case "ar-SA": "يومك، بهدوء"
        case "fr-FR": "Ta journée, au calme"
        default: "Your day, quietly"
        }
    }

    /// A gradient with the headline, `pixelWidth` wide in the image's shape.
    static func image(for image: LiveArtworkImage, pixelWidth: Int) -> CGImage? {
        guard let place = image.place else { return nil }
        let locale = image.placementID.components(separatedBy: "-").dropFirst(2).joined(separator: "-")
        return draw(place, headline: headline(locale), hue: hue(locale), pixelWidth: pixelWidth)
    }

    /// A PNG of `place`'s full size, as a person would add.
    static func file(_ place: StoreArtworkPlace, locale: String, name: String) -> ScreenshotHandChosenFile {
        let size = place.kind.pixelSize
        let image = draw(place, headline: headline(locale), hue: hue(locale) + 0.35, pixelWidth: size.width)
        return ScreenshotHandChosenFile(fileName: name, data: image.flatMap(ScreenshotPNG.data) ?? Data())
    }

    private static func hue(_ locale: String) -> CGFloat {
        CGFloat(locale.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 360) / 360
    }

    private static func draw(_ place: StoreArtworkPlace, headline: String, hue: CGFloat, pixelWidth: Int) -> CGImage? {
        let shape = place.kind.pixelSize
        let width = max(1, pixelWidth)
        let height = max(1, Int((Double(width) * Double(shape.height) / Double(max(1, shape.width))).rounded()))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        let top = color(hue: hue, brightness: 0.62)
        let bottom = color(hue: hue + 0.08, brightness: 0.32)
        if let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        }
        context.setFillColor(CGColor(gray: 1, alpha: 0.16))
        let circle = CGFloat(height) * 0.9
        context.fillEllipse(in: CGRect(x: CGFloat(width) - circle * 0.8, y: -circle * 0.25, width: circle, height: circle))
        let font = CTFontCreateWithName("Futura-Bold" as CFString, CGFloat(height) * 0.14, nil)
        let text = NSAttributedString(string: headline, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
        ])
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        context.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2, y: CGFloat(height) * 0.44)
        CTLineDraw(line, context)
        return context.makeImage()
    }

    private static func color(hue: CGFloat, brightness: CGFloat) -> CGColor {
        // A plain HSB to RGB, saturation 0.55.
        let hue = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let chroma = brightness * 0.55
        let second = chroma * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1))
        let base = brightness - chroma
        let (red, green, blue): (CGFloat, CGFloat, CGFloat) = switch Int(hue) {
        case 0: (chroma, second, 0)
        case 1: (second, chroma, 0)
        case 2: (0, chroma, second)
        case 3: (0, second, chroma)
        case 4: (second, 0, chroma)
        default: (chroma, 0, second)
        }
        return CGColor(srgbRed: red + base, green: green + base, blue: blue + base, alpha: 1)
    }
}
#endif
