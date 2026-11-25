//
//  ScreenshotCoverageTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · screenshots each device's languages have")
struct ScreenshotCoverageTests {
    private static let codes = ["en-US", "de-DE", "ja", "fr-FR"]
    private static var locales: [StoreLocale] { codes.compactMap(StoreLocaleCatalog.locale(code:)) }

    private static func set(_ locale: String, _ type: ScreenshotDisplayType, count: Int = 3) -> LiveScreenshotSet {
        LiveScreenshotSet(
            id: "\(locale)-\(type.rawValue)", locale: locale, displayType: type,
            screenshots: (0..<count).map { LiveScreenshot(id: "\(locale)-\($0)", fileName: "\($0).png") }
        )
    }

    private static var live: LiveScreenshots {
        LiveScreenshots(screenshotSets: [
            set("en-US", .iPhone), set("ja", .iPhone), set("fr-FR", .iPhone),
            set("en-US", .iPad), set("ja", .iPad),
            set("en-US", .mac),
            // Left empty by an upload that never finished: not the language's own.
            set("de-DE", .iPhone, count: 0),
        ])
    }

    @Test func readsEachDevicesLanguagesFromTheLiveSets() {
        let coverage = ScreenshotCoverage(live: Self.live, pageLocales: Self.locales)
        #expect(coverage.localesByDevice[.iPhone] == ["en-US", "ja", "fr-FR"])
        #expect(coverage.localesByDevice[.iPad] == ["en-US", "ja"])
        #expect(coverage.locales == ["en-US", "ja", "fr-FR"])
        #expect(coverage.pageLocaleCount == 4)
    }

    @Test func theContextTakesTheLanguagesWithTheirOwnScreenshots() {
        var context = AnalyticsContext(primaryLocale: StoreLocaleCatalog.locale(code: "en-US"), pageLocales: Self.locales)
        #expect(context.hasOwnScreenshots(for: "DE") == nil)
        context.setScreenshots(Self.live)
        #expect(context.hasOwnScreenshots(for: "DE") == false)
        #expect(context.hasOwnScreenshots(for: "JP") == true)
        #expect(context.screenshotCoverage?.localesByDevice[.mac] == ["en-US"])
    }

    @Test(arguments: [
        ("iPhone", ScreenshotDisplayType.iPhone), ("iPod", .iPhone), ("iPad", .iPad), ("Desktop", .mac),
        ("Apple Watch", .watch), ("Apple Vision Pro", .visionPro), ("Apple TV", .appleTV),
    ])
    func namesTheSetForAppleReportsDevice(device: String, expected: ScreenshotDisplayType) {
        #expect(ScreenshotCoverage.displayType(forReportDevice: device) == expected)
    }

    @Test func anUnknownDeviceHasNoSummary() {
        let coverage = ScreenshotCoverage(live: Self.live, pageLocales: Self.locales)
        #expect(ScreenshotCoverage.displayType(forReportDevice: "Unknown") == nil)
        #expect(coverage.summary(forReportDevice: "Unknown") == nil)
    }

    @Test func aDeviceInEveryLanguageIsNoWarning() throws {
        let coverage = ScreenshotCoverage(localesByDevice: [.iPhone: Set(Self.codes)], pageLocaleCount: 4)
        let summary = try #require(coverage.summary(forReportDevice: "iPhone"))
        #expect(!summary.isWarning)
        #expect(summary.text.contains("4"))
    }

    @Test func iPadInSomeLanguagesSaysTheRestShowTheIPhoneSet() throws {
        let coverage = ScreenshotCoverage(live: Self.live, pageLocales: Self.locales)
        let summary = try #require(coverage.summary(forReportDevice: "iPad"))
        #expect(summary.isWarning)
        #expect(summary.text.contains("2"))
        #expect(summary.text.contains("4"))
        #expect(summary.text.contains("iPhone set"))
    }

    @Test func aSetInOneLanguageNamesIt() throws {
        let coverage = ScreenshotCoverage(live: Self.live, pageLocales: Self.locales)
        let summary = try #require(coverage.summary(forReportDevice: "Desktop"))
        #expect(summary.isWarning)
        #expect(summary.text.contains("English"))
    }

    @Test func noIPadSetSaysTheIPhoneSetShows() throws {
        let coverage = ScreenshotCoverage(localesByDevice: [.iPhone: ["en-US"]], pageLocaleCount: 1)
        let summary = try #require(coverage.summary(forReportDevice: "iPad"))
        #expect(summary.isWarning)
        #expect(summary.text.contains("iPhone set"))
    }
}
