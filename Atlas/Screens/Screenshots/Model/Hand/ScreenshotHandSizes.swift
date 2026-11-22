//
//  ScreenshotHandSizes.swift
//  Atlas
//

import Foundation

/// The sizes App Store Connect takes for each device's screenshots,
/// upright; turned 90° they're taken too. The same rule Autopilot's
/// captures follow: nothing is ever scaled to fit.
enum ScreenshotHandSizes {
    static func accepted(on display: ScreenshotDisplayType) -> [PixelSize] {
        switch display {
        case .iPhone: [PixelSize(width: 1320, height: 2868), PixelSize(width: 1290, height: 2796), PixelSize(width: 1260, height: 2736)]
        case .iPhoneDuo: [display.portraitPixelSize]
        case .iPad: [PixelSize(width: 2064, height: 2752), PixelSize(width: 2048, height: 2732)]
        case .mac:
            [
                PixelSize(width: 2880, height: 1800), PixelSize(width: 2560, height: 1600),
                PixelSize(width: 1440, height: 900), PixelSize(width: 1280, height: 800),
            ]
        case .watch: [PixelSize(width: 422, height: 514), PixelSize(width: 410, height: 502)]
        case .appleTV: [PixelSize(width: 3840, height: 2160), PixelSize(width: 1920, height: 1080)]
        case .visionPro: [PixelSize(width: 3840, height: 2160)]
        }
    }

    static func accepts(_ size: PixelSize, on display: ScreenshotDisplayType) -> Bool {
        accepted(on: display).contains { $0 == size || $0.rotated == size }
    }

    /// "1320 × 2868", the size the device's set is made at.
    static func main(on display: ScreenshotDisplayType) -> String {
        accepted(on: display).first?.title ?? display.portraitPixelSize.title
    }

    /// "1290 × 2796 or 1260 × 2736": the other sizes it takes; nil when
    /// there's only one.
    static func others(on display: ScreenshotDisplayType) -> String? {
        let rest = accepted(on: display).dropFirst().map(\.title)
        guard let last = rest.last else { return nil }
        guard rest.count > 1 else { return last }
        return String(localized: "\(rest.dropLast().joined(separator: ", ")) or \(last)")
    }

    /// "1320 × 2868, 1290 × 2796 or 1260 × 2736".
    static func all(on display: ScreenshotDisplayType) -> String {
        let all = accepted(on: display).map(\.title)
        guard let last = all.last, all.count > 1 else { return all.first ?? "" }
        return String(localized: "\(all.dropLast().joined(separator: ", ")) or \(last)")
    }
}
