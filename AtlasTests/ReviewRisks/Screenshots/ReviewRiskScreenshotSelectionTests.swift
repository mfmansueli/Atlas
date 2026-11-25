//
//  ReviewRiskScreenshotSelectionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which live screenshots the check reads: the primary language's sets on
/// every device, up to 4 other languages' iPhone sets, 10 per set, 60 in
/// all, and none without an image yet.
@Suite("App Review risks · screenshots picked")
struct ReviewRiskScreenshotSelectionTests {
    private func set(_ locale: String, _ display: ScreenshotDisplayType, count: Int, withImages: Bool = true) -> LiveScreenshotSet {
        let screenshots = (0..<count).map { index in
            LiveScreenshot(
                id: "\(locale)-\(display.rawValue)-\(index)",
                fileName: "\(index).png",
                checksum: "sum-\(locale)-\(index)",
                pixelSize: display.defaultPixelSize,
                imageURLTemplate: withImages ? "https://example.com/{w}x{h}.{f}" : nil
            )
        }
        return LiveScreenshotSet(id: "\(locale)-\(display.rawValue)", locale: locale, displayType: display, screenshots: screenshots)
    }

    @Test func thePrimaryLanguageOnEveryDeviceThenFourOthersOnIPhone() {
        let live = LiveScreenshots(screenshotSets: [
            set("de-DE", .iPhone, count: 2), set("en-US", .iPad, count: 3), set("en-US", .iPhone, count: 12), set("fr-FR", .iPhone, count: 2),
            set("ja", .iPhone, count: 1), set("es-ES", .iPhone, count: 1), set("it", .iPhone, count: 1), set("de-DE", .iPad, count: 2),
        ])
        let selection = ReviewRiskScreenshotSelection(live: live, primary: "en-US", locales: ["en-US", "de-DE", "fr-FR", "ja", "es-ES", "it"])
        let sets = selection.picks.map { "\($0.locale) \($0.displayType.rawValue)" }
        #expect(sets.prefix(10).allSatisfy { $0 == "en-US APP_IPHONE_67" })
        #expect(selection.picks.filter { $0.locale == "en-US" && $0.displayType == .iPad }.count == 3)
        #expect(Set(selection.picks.map(\.locale)) == ["en-US", "de-DE", "fr-FR", "ja", "es-ES"])
        #expect(!selection.picks.contains { $0.locale == "de-DE" && $0.displayType == .iPad })
        #expect(selection.picks.count == 19)
        #expect(selection.unreadCount == 24 - 19)
        #expect(selection.picks.first?.slot == 1)
        #expect(selection.picks.filter { $0.locale == "en-US" && $0.displayType == .iPhone }.last?.slot == 10)
    }

    @Test func atMostSixtyInAll() {
        let live = LiveScreenshots(screenshotSets: ScreenshotDisplayType.allCases.map { set("en-US", $0, count: 10) })
        let selection = ReviewRiskScreenshotSelection(live: live, primary: "en-US", locales: ["en-US"])
        #expect(selection.picks.count == ReviewRiskScreenshotSelection.maximum)
        #expect(selection.unreadCount == ScreenshotDisplayType.allCases.count * 10 - 60)
    }

    @Test func screenshotsWithoutAnImageYetAreSkipped() {
        let live = LiveScreenshots(screenshotSets: [set("en-US", .iPhone, count: 3, withImages: false), set("en-US", .iPad, count: 1)])
        let selection = ReviewRiskScreenshotSelection(live: live, primary: "en-US", locales: ["en-US"])
        #expect(selection.picks.map(\.displayType) == [.iPad])
        #expect(selection.unreadCount == 3)
    }
}
