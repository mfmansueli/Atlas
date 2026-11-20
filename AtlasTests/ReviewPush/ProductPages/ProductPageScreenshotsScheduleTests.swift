//
//  ProductPageScreenshotsScheduleTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// When a custom product page's own screenshots go out in a push (board
/// 52): after the app's ordered changes (the page and its texts among
/// them), one language's devices one after the other, other languages and
/// other apps side by side; and last in the push.
@MainActor
@Suite("Product page screenshots schedule")
struct ProductPageScreenshotsScheduleTests {
    private func shots(_ id: String, app: StoreApp.ID = "lumen", locale: String, display: ScreenshotDisplayType = .iPhone) -> PendingChange {
        let push = ProductPageScreenshotsPush(.init(
            appID: app, pageID: "page-1", pageName: "Private diary", currentDeepLink: nil, locale: locale, displayType: display,
            files: [.init(path: "/tmp/1.png", fileName: "1.png", fileSize: 10, checksum: "x")]
        ))
        return PendingChange(
            id: id, appID: app, section: .productPages, group: "G", title: id, oldValue: "", newValue: "new", requests: [push.request]
        )
    }

    private func change(_ id: String, section: AppWorkspaceSection, method: PushRequest.Method, path: String) -> PendingChange {
        PendingChange(
            id: id, appID: "lumen", section: section, group: "G", title: id, oldValue: "", newValue: "new",
            requests: [PushRequest(method: method, path: path, body: nil)]
        )
    }

    @Test func screenshotsWaitForThePageAndForTheirOwnLanguageOnly() {
        let waits = PushSchedule.waits(for: [
            change("page.new", section: .productPages, method: .post, path: "/v1/appCustomProductPages"),
            shots("en.iPhone", locale: "en-US"),
            shots("en.iPad", locale: "en-US", display: .iPad),
            shots("de.iPhone", locale: "de-DE"),
            shots("habitat.en", app: "habitat", locale: "en-US"),
            change("en.whatsNew", section: .storePage, method: .patch, path: "/v1/appStoreVersionLocalizations/en"),
            change("page.texts", section: .productPages, method: .patch, path: "/v1/appCustomProductPageLocalizations/loc-en"),
        ])
        #expect(waits[1] == [0])
        #expect(waits[2] == [0, 1])
        #expect(waits[3] == [0])
        #expect(waits[4] == [])
        #expect(waits[5] == [])
        // An ordered change never waits for screenshots.
        #expect(waits[6] == [0])
    }

    @Test func screenshotsGoLastInThePush() {
        let ordered = ProductPageScreenshotsPushOrder.sorted([
            shots("en.iPhone", locale: "en-US"),
            change("page.new", section: .productPages, method: .post, path: "/v1/appCustomProductPages"),
            shots("de.iPhone", locale: "de-DE"),
            change("page.texts", section: .productPages, method: .patch, path: "/v1/appCustomProductPageLocalizations/loc-en"),
        ])
        #expect(ordered.map(\.id) == ["page.new", "page.texts", "en.iPhone", "de.iPhone"])
    }
}
