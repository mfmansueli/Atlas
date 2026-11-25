//
//  FakeStorePageServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// `StorePageServices` with canned content per version, an optional
/// failure, and a count of what was asked for.
@MainActor
final class FakeStorePageServices: StorePageServices {
    /// What `content(for:versionID:)` returns for a version; `nil` picks the
    /// first entry of `defaultVersionID`.
    var contents: [String: StorePageContent]
    var defaultVersionID: String
    var error: (any Error)?
    var inAppTextsContent = InAppTextsContent.empty
    /// Awaited before the texts are returned, to hold a read in progress.
    var beforeInAppTexts: (() async -> Void)?
    /// What `customerReviews(for:limit:)` returns, or why it fails.
    var reviews: [CustomerReview] = []
    var reviewsError: (any Error)?
    var screenshots: any ScreenshotsServices = FakeScreenshotsServices()
    /// What the app's project supports; nil when no assistant reported it.
    var appSupport: AppSupportCenter?
    let translator: any ListingTranslator
    let machineTranslations: any MachineTranslationStore

    private(set) var contentRequests: [String?] = []
    private(set) var summaryCount = 0

    init(
        contents: [StorePageContent] = [StorePageContentFixtures.editable, StorePageContentFixtures.live],
        translator: any ListingTranslator = FakeListingTranslator(),
        machineTranslations: any MachineTranslationStore = InMemoryMachineTranslationStore()
    ) {
        self.contents = Dictionary(uniqueKeysWithValues: contents.map { ($0.version.id, $0) })
        defaultVersionID = contents.first?.version.id ?? ""
        self.translator = translator
        self.machineTranslations = machineTranslations
    }

    func summary(for app: StoreApp) async throws -> StorePageSummary {
        summaryCount += 1
        let content = try await content(for: app, versionID: nil)
        return content.summary(machineTranslated: MachineTranslationScope.tags(in: machineTranslations, appID: app.id, ids: content.ids))
    }

    func content(for _: StoreApp, versionID: String?) async throws -> StorePageContent {
        contentRequests.append(versionID)
        if let error { throw error }
        guard let content = contents[versionID ?? defaultVersionID] else { throw AppStoreConnectError.notFound(detail: nil) }
        return content
    }

    func inAppTexts(for _: StoreApp) async throws -> InAppTextsContent {
        await beforeInAppTexts?()
        if let error { throw error }
        return inAppTextsContent
    }

    func customerReviews(for _: StoreApp, limit: Int) async throws -> [CustomerReview] {
        if let reviewsError { throw reviewsError }
        return Array(reviews.prefix(limit))
    }
}
