//
//  DebugProductPagesServices.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation

/// Lumen Journal's product pages for DEBUG scenes; other apps have none.
@MainActor
struct DebugProductPagesServices: ProductPagesServices {
    var error: AppStoreConnectError?
    var isEmpty = false
    /// 70 pages: the most Apple allows.
    var isAtLimit = false
    /// No version approved yet: keywords can't be chosen.
    var hasNoApprovedVersion = false
    /// Never answers, for the loading scene.
    var neverLoads = false
    /// Submitting fails with this.
    var submitError: AppStoreConnectError?

    func pages(for app: StoreApp) async throws -> ProductPagesSnapshot {
        if neverLoads { try await Task.sleep(for: .seconds(3600)) }
        if let error { throw error }
        guard app.id == DebugProductPagesData.appID else {
            return ProductPagesSnapshot(pages: [], defaultPage: ProductPageDefault(), readAt: DebugProductPagesData.now)
        }
        var snapshot = DebugProductPagesData.snapshot
        if isEmpty { snapshot.pages = [] }
        if isAtLimit {
            let filler = (snapshot.pages.count..<(ProductPagesSnapshot.limit - 1)).map { index in
                ProductPage(
                    id: "filler-\(index)", name: "Campaign \(index + 1)", url: DebugProductPagesData.link("filler-\(index)"), isVisible: false,
                    versions: [ProductPageVersion(id: "filler-v-\(index)", number: 1, state: .approved)]
                )
            }
            snapshot.pages += filler
        }
        if hasNoApprovedVersion {
            snapshot.defaultPage.approvedVersionString = nil
            for index in snapshot.defaultPage.languages.indices {
                snapshot.defaultPage.languages[index].approvedKeywords = []
            }
        }
        return snapshot
    }

    func submit(versionID _: String, of _: StoreApp) async throws {
        if let submitError { throw submitError }
    }

    var canCancelSubmission: Bool { true }

    func cancelSubmission(versionID _: String, of _: StoreApp) async throws {}

    // MARK: - Screenshots

    /// The default page's sets: the ones Screenshots pushed on Oct 12, in
    /// the language (English where none was drawn).
    func defaultScreenshots(localizationID _: String, locale: String) async throws -> [LiveScreenshotSet] {
        Self.sets(locale: locale)
    }

    /// A page's own sets: the same screens, the third one first.
    func pageScreenshots(localizationID _: String, locale: String) async throws -> [LiveScreenshotSet] {
        Self.sets(locale: locale).map { set in
            var own = set
            let order = [2, 0, 4, 1, 3].filter(set.screenshots.indices.contains)
            own.id = "own|\(set.id)"
            own.screenshots = order.map { set.screenshots[$0] }
            return own
        }
    }

    func screenshotImage(_ screenshot: LiveScreenshot, pixelWidth: Int) async -> CGImage? {
        await Self.screenshots.liveImage(screenshot, pixelWidth: pixelWidth)
    }

    private static func sets(locale: String) -> [LiveScreenshotSet] {
        let live = ScreenshotsDebugDocuments.live.screenshotSets.filter { $0.id.hasPrefix("set|") }
        let shown = live.contains { $0.locale == locale } ? locale : "en-US"
        return live.filter { $0.locale == shown }
    }

    private static let screenshots: DebugScreenshotsServices = {
        let services = DebugScreenshotsServices()
        services.drawsPushedLiveSets = true
        return services
    }()
}
#endif
