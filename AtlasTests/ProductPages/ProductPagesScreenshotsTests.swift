//
//  ProductPagesScreenshotsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The editor's Screenshots and App Previews, read only: a language's own,
/// else the default page's; a copy shows the page it copies.
@MainActor
@Suite("Custom Product Pages screenshots")
struct ProductPagesScreenshotsTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    private func model() async -> ProductPagesViewModel {
        let model = ProductPagesViewModel(
            app: DebugFixtures.lumen, services: DebugProductPagesServices(), store: Sample.store(),
            queue: ChangeQueue(changes: Sample.pendingChanges)
        )
        await model.load()
        return model
    }

    @Test func aLanguageWithItsOwnShowsThemAndTheOthersTheDefaultPages() async throws {
        let model = await model()
        let prompts = try ProductPagesTestModel.page(model, PageID.prompts)
        #expect(model.hasOwnScreenshots(prompts, locale: "en-US", device: .iPhone))
        #expect(!model.hasOwnScreenshots(prompts, locale: "en-US", device: .iPad))
        #expect(!model.hasOwnScreenshots(prompts, locale: "de-DE", device: .iPhone))
        #expect(model.ownScreenshotsKey(prompts, locale: "en-US") == "own.prompts-en-US")
        #expect(model.ownScreenshotsKey(prompts, locale: "de-DE") == nil)
        #expect(model.defaultScreenshotsKey("de-DE") == "default.loc-de-DE")
        // A language the default page doesn't have shows the primary's.
        #expect(model.defaultScreenshotsKey("xx") == "default.loc-en-US")
        #expect(model.screenshots(nil, device: .iPhone) == .loaded([]))
        #expect(model.shownScreenshots(of: prompts, locale: "en-US", device: .iPhone).isLoading)

        await model.loadScreenshots(of: prompts, locale: "en-US")
        #expect(model.screenshotSets["own.prompts-en-US"]?.value != nil)
        #expect(model.screenshotSets["default.loc-en-US"]?.value != nil)
        #expect(model.screenshotsNote(of: prompts, locale: "de-DE", device: .iPhone) == "German shows the default page’s German screenshots.")
    }

    @Test func aDraftShowsTheDefaultPagesOrThePageItCopies() async throws {
        let model = await model()
        let draft = try ProductPagesTestModel.page(model, PageID.privateDiary)
        #expect(model.screenshotPage(of: draft) == nil)
        #expect(!model.hasOwnScreenshots(draft, locale: "en-US", device: .iPhone))

        let copy = try #require(model.create(NewProductPage(
            name: "Evening prompts", start: .copy(pageID: PageID.prompts, name: "Prompts"), locales: ["en-US"]
        )))
        let copyPage = try ProductPagesTestModel.page(model, copy.id)
        #expect(model.screenshotPage(of: copyPage)?.id == PageID.prompts)
        #expect(model.hasOwnScreenshots(copyPage, locale: "en-US", device: .iPhone))
        #expect(model.selectedPageID == copy.id)
    }

    /// Alba's default page has an iPhone Duo set before its 6.9" one: the
    /// iPhone row shows the 6.9" set, never the Duo's wide inner display.
    @Test func iPhoneShowsTheLargestDisplayNotDuo() {
        func set(_ type: ScreenshotDisplayType, count: Int = 2) -> LiveScreenshotSet {
            let shots = (0..<count).map { LiveScreenshot(id: "\(type.rawValue)-\($0)", fileName: "\($0).png") }
            return LiveScreenshotSet(id: type.rawValue, locale: "en-US", displayType: type, screenshots: shots)
        }
        let sets = [set(.iPhoneDuo), set(.iPhone), set(.iPad)]
        #expect(ProductPagesViewModel.shownSet(of: sets, on: .iPhone)?.displayType == .iPhone)
        #expect(ProductPagesViewModel.shownSet(of: sets, on: .iPad)?.displayType == .iPad)
        // Only Duo has screenshots: it's still better than nothing.
        let duoOnly = [set(.iPhoneDuo), set(.iPhone, count: 0)]
        #expect(ProductPagesViewModel.shownSet(of: duoOnly, on: .iPhone)?.displayType == .iPhoneDuo)
    }
}
