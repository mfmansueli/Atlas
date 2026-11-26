//
//  ScreenshotsTakeIconTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Screenshots section's models are made (or read ahead) before the
/// sidebar finds the icons; they take the icon later, so the language
/// page's "On the App Store" preview stops drawing the app's letter.
@MainActor
@Suite("Screenshots models take the app icon")
struct ScreenshotsTakeIconTests {
    private let icon = AppIcon.remote(URL(string: "https://example.com/icon.png")!)

    private var appWithoutIcon: StoreApp {
        var app = StorePageContentFixtures.app
        app.icon = nil
        return app
    }

    @Test func aLoadedSectionHandsTheIconToItsScreenshotsModel() async throws {
        let section = ScreenshotsSectionModel(app: appWithoutIcon, services: FakeStorePageServices())
        await section.load()
        let screenshots = try #require(section.screenshots)
        #expect(screenshots.app.icon == nil)
        section.takeIcon(icon)
        #expect(section.app.icon == icon)
        #expect(screenshots.app.icon == icon)
        #expect(screenshots.studio.app.icon == icon)
    }

    @Test func aScreenshotsModelMadeAfterTheIconHasIt() async throws {
        let section = ScreenshotsSectionModel(app: appWithoutIcon, services: FakeStorePageServices())
        section.takeIcon(icon)
        await section.load()
        let screenshots = try #require(section.screenshots)
        #expect(screenshots.app.icon == icon)
    }

    @Test func noIconLeavesTheOneItHas() async throws {
        var app = appWithoutIcon
        app.icon = icon
        let section = ScreenshotsSectionModel(app: app, services: FakeStorePageServices())
        await section.load()
        section.takeIcon(nil)
        let screenshots = try #require(section.screenshots)
        #expect(section.app.icon == icon)
        #expect(screenshots.app.icon == icon)
    }

    @Test func takingTheIconKeepsTheRestOfTheApp() {
        let services = FakeScreenshotsServices(document: ScreenshotsDebugDocuments.standard, live: ScreenshotsDebugDocuments.live)
        let context = ScreenshotsContext(primaryLocale: .englishUS, version: ScreenshotsTestFixtures.editableVersion)
        let model = ScreenshotsViewModel(app: ScreenshotsTestFixtures.app, services: services, context: context)
        model.takeIcon(icon)
        #expect(model.app.icon == icon)
        #expect(model.app.id == ScreenshotsTestFixtures.app.id)
        #expect(model.app.name == ScreenshotsTestFixtures.app.name)
    }
}
