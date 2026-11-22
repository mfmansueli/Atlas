//
//  AlbaCaptureFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// A screenshot document shaped like Alba's on 2026-11-22, when its run was
/// gone: six slots named only by their capture files
/// (`ja/iPhone 17 Pro Max-01_Today's phrase.png`), captured by Autopilot on
/// Nov 11 in en-US and ja on iPhone (1320 × 2868), iPhone Duo (slots 1, 3
/// and 5 on the inner display, 2853 × 2007; 2, 4 and 6 on the cover
/// display, 1398 × 2034) and iPad (2752 × 2064, landscape), and fr-FR on
/// iPhone only.
enum AlbaCaptureFixtures {
    nonisolated static let slotNames = ["Today's phrase", "Animated scenes", "Styles", "Streak", "Topics", "My Phrases"]
    nonisolated static let capturedAt = Date(timeIntervalSinceReferenceDate: 784_515_617)
    nonisolated static let iPhone = PixelSize(width: 1320, height: 2868)
    nonisolated static let duoInner = PixelSize(width: 2853, height: 2007)
    nonisolated static let duoCover = PixelSize(width: 1398, height: 2034)
    nonisolated static let iPad = PixelSize(width: 2752, height: 2064)

    /// The document, its captions in en-US.
    nonisolated static func document() -> ScreenshotsDocument {
        var captures = CaptureIndex()
        for locale in ["en-US", "ja"] {
            for slot in slotNames.indices {
                captures.add(capture(locale, .iPhone, slot: slot, size: iPhone))
                captures.add(capture(locale, .iPhoneDuo, slot: slot, size: slot.isMultiple(of: 2) ? duoInner : duoCover))
                captures.add(capture(locale, .iPad, slot: slot, size: iPad))
            }
        }
        for slot in slotNames.indices {
            captures.add(capture("fr-FR", .iPhone, slot: slot, size: iPhone))
        }
        var document = ScreenshotsDocument(captures: captures, scope: LocaleScope(primary: "en-US"))
        for (slot, name) in slotNames.enumerated() {
            document.captions.setCaption(ScreenshotCaption(headline: "\(name) headline", subhead: nil, provenance: .written), locale: "en-US", slot: slot)
        }
        return document
    }

    /// "ja/iPhone 17 Pro Max-01_Today's phrase.png", id "ja-iphone-1".
    nonisolated static func capture(_ locale: String, _ display: ScreenshotDisplayType, slot: Int, size: PixelSize) -> ScreenshotCapture {
        let fileName = String(format: "%@/%@-%02d_%@.png", locale, display.deviceName, slot + 1, slotNames[slot])
        return ScreenshotCapture(
            id: "\(locale)-\(display.mcpValue)-\(slot + 1)", locale: locale, displayType: display, slot: slot, source: .autopilot,
            fileName: fileName, pixelSize: size, importedAt: capturedAt.addingTimeInterval(Double(slot))
        )
    }
}
#endif
