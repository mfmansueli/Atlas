//
//  KeptProductPagesServices.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// Product Pages' services for assistant tools: an app's pages as the
/// section read them while that read is fresh (`kept`), so a tool sees what
/// the person sees without reading App Store Connect again; else `base`
/// reads them. Everything else goes to `base`.
@MainActor
struct KeptProductPagesServices: ProductPagesServices {
    let base: any ProductPagesServices
    let kept: @MainActor (StoreApp.ID) -> ProductPagesSnapshot?

    func pages(for app: StoreApp) async throws -> ProductPagesSnapshot {
        if let snapshot = kept(app.id) { return snapshot }
        return try await base.pages(for: app)
    }

    func pageScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet] {
        try await base.pageScreenshots(localizationID: localizationID, locale: locale)
    }

    func defaultScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet] {
        try await base.defaultScreenshots(localizationID: localizationID, locale: locale)
    }

    func submit(versionID: String, of app: StoreApp) async throws {
        try await base.submit(versionID: versionID, of: app)
    }

    var canCancelSubmission: Bool { base.canCancelSubmission }

    func cancelSubmission(versionID: String, of app: StoreApp) async throws {
        try await base.cancelSubmission(versionID: versionID, of: app)
    }

    func screenshotImage(_ screenshot: LiveScreenshot, pixelWidth: Int) async -> CGImage? {
        await base.screenshotImage(screenshot, pixelWidth: pixelWidth)
    }
}
