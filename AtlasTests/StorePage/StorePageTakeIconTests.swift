//
//  StorePageTakeIconTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Section models kept from before the icons arrived take the icon later,
/// so the App Store preview stops drawing the app's letter.
@MainActor
@Suite("Kept models take the app icon")
struct StorePageTakeIconTests {
    private let icon = AppIcon.remote(URL(string: "https://example.com/icon.png")!)

    private var appWithoutIcon: StoreApp {
        var app = DebugFixtures.lumen
        app.icon = nil
        return app
    }

    @Test func storePageModelTakesTheIcon() {
        let model = StorePageViewModel(app: appWithoutIcon, services: DebugStorePageServices(), queue: ChangeQueue())
        model.takeIcon(icon)
        #expect(model.app.icon == icon)
    }

    @Test func noIconLeavesTheOneItHas() {
        var app = appWithoutIcon
        app.icon = icon
        let model = StorePageViewModel(app: app, services: DebugStorePageServices(), queue: ChangeQueue())
        model.takeIcon(nil)
        #expect(model.app.icon == icon)
    }

    @Test func productPagesModelTakesTheIcon() {
        let model = ProductPagesViewModel(app: appWithoutIcon, services: DebugProductPagesServices(), store: ProductPagesStore(), queue: ChangeQueue())
        model.takeIcon(icon)
        #expect(model.app.icon == icon)
    }
}
