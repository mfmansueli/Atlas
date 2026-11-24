//
//  ProductPagesServices.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What Product Pages needs from App Store Connect. `LiveProductPagesServices`
/// reads it; tests and DEBUG scenes use canned pages. Changes go through
/// Review & Push like every other edit.
@MainActor
protocol ProductPagesServices {
    /// The app's custom product pages with their versions and languages,
    /// and the default page.
    func pages(for app: StoreApp) async throws -> ProductPagesSnapshot
    /// A page language's own screenshot sets.
    func pageScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet]
    /// The default page's screenshot sets in a language.
    func defaultScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet]
    /// Sends a page's version to App Review by itself, without a version
    /// of the app.
    func submit(versionID: String, of app: StoreApp) async throws
    /// Whether a page waiting for review can be taken back from here.
    var canCancelSubmission: Bool { get }
    /// Takes a page's version back from App Review while it waits: cancels
    /// the submission it went in, when it went alone.
    func cancelSubmission(versionID: String, of app: StoreApp) async throws
    /// A live screenshot, downloaded at `pixelWidth`.
    func screenshotImage(_ screenshot: LiveScreenshot, pixelWidth: Int) async -> CGImage?
}

extension ProductPagesServices {
    func pageScreenshots(localizationID _: String, locale _: String) async throws -> [LiveScreenshotSet] { [] }
    func defaultScreenshots(localizationID _: String, locale _: String) async throws -> [LiveScreenshotSet] { [] }

    var canCancelSubmission: Bool { false }

    func cancelSubmission(versionID _: String, of _: StoreApp) async throws {
        throw AppStoreConnectError.unexpectedPayload
    }

    func screenshotImage(_ screenshot: LiveScreenshot, pixelWidth: Int) async -> CGImage? {
        guard let url = screenshot.imageURL(width: pixelWidth),
              let data = try? await RemoteImageCache.shared.data(for: url) else { return nil }
        return ScreenshotPNG.image(data)
    }
}
