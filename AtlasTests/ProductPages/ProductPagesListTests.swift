//
//  ProductPagesListTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 50: the list of pages in its order, the 70 limit, the numbers
/// from Analytics, Analytics' Open Page and the Overview's card.
@MainActor
@Suite("Custom Product Pages list")
struct ProductPagesListTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    @Test func visiblePagesComeFirstThenDraftsRejectedAndHidden() async throws {
        let model = await ProductPagesTestModel.make()
        #expect(model.pages.map(\.name) == [
            "Prompts", "Mood tracking", "Sleep & wind-down", "Private diary", "Year in review", "Therapists",
        ])
        #expect(model.countText == "6 of 70")
        #expect(!model.isAtLimit)
        #expect(model.canMakePages)
        #expect(try model.visibilityText(of: ProductPagesTestModel.page(model, PageID.therapists)) == "Hidden")
        #expect(try model.nextVersionText(of: ProductPagesTestModel.page(model, PageID.sleep)) == "New version in review")
    }

    @Test func atTheLimitNoPageCanBeMadeAndHiddenOnesCanBeListed() async {
        let services = FakeProductPagesServices()
        let filler = (services.snapshot.pages.count..<(ProductPagesSnapshot.limit - 1)).map { index in
            ProductPage(
                id: "filler-\(index)", name: "Campaign \(index)", url: nil, isVisible: true,
                versions: [ProductPageVersion(id: "filler-v-\(index)", number: 1, state: .approved)]
            )
        }
        services.snapshot.pages += filler
        let model = await ProductPagesTestModel.make(services)
        #expect(model.pageCount == 70)
        #expect(model.isAtLimit)
        #expect(!model.canMakePages)
        #expect(model.pageSuggestions.isEmpty)
        model.showsOnlyHiddenAndRejected = true
        #expect(model.listedPages.map(\.name) == ["Year in review", "Therapists"])
    }

    @Test func aReadThatFailsLaterKeepsWhatWasReadAndItsEdits() async {
        let services = FakeProductPagesServices()
        let model = await ProductPagesTestModel.make(services)
        services.readError = .server(statusCode: 503, detail: "Later.")
        await model.load(force: true)
        #expect(model.isOffline)
        #expect(model.pages.count == 6)
        #expect(!model.canMakePages)
        #expect(model.canChange)
    }

    @Test func aKeyThatCantChangePagesOnlyReads() async throws {
        let store = Sample.store()
        store.setKeyCannotChange(true, for: Sample.appID)
        let model = await ProductPagesTestModel.make(store: store)
        #expect(!model.canChange)
        #expect(!model.canMakePages)
        #expect(try model.primaryActionTitle(of: ProductPagesTestModel.page(model, PageID.privateDiary)) == nil)
    }

    @Test func theNumbersComeFromAnalytics() async throws {
        let model = await ProductPagesTestModel.make()
        model.setNumbers(from: Sample.analyticsArchive.pageFacts)
        let prompts = try ProductPagesTestModel.page(model, PageID.prompts)
        #expect(model.numbers(of: prompts)?.impressions == 18400)
        #expect(model.comparison(of: prompts) != nil)
        #expect(try model.numbers(of: ProductPagesTestModel.page(model, PageID.privateDiary)) == nil)
        #expect(model.defaultNumbers?.downloads == 2550)
    }

    /// Analytics' Open Page names the page as Apple's reports do.
    @Test func openPageFindsAPageByItsName() async {
        let model = await ProductPagesTestModel.make()
        #expect(model.openPage(named: "Mood tracking"))
        #expect(model.selectedPageID == PageID.mood)
        model.back()
        #expect(model.selectedPageID == nil)
        // A draft isn't in Analytics.
        #expect(!model.openPage(named: "Private diary"))
        #expect(!model.openPage(named: "Spring sale"))
    }

    @Test func theOverviewCardSumsUpThePages() async {
        let model = await ProductPagesTestModel.make()
        model.setNumbers(from: Sample.analyticsArchive.pageFacts)
        let summary = ProductPagesOverviewSummary.make(model)
        #expect(summary?.line == "6 pages · 3 visible on the App Store · 1 rejected")
        #expect(summary?.suggestionCount == 2)
        #expect(summary?.best?.hasPrefix("Best: “") == true)
    }

    @Test func theOverviewCardSaysWhenThereAreNoPages() async {
        let services = FakeProductPagesServices()
        services.snapshot.pages = []
        let model = await ProductPagesTestModel.make(
            services, store: Sample.store(Sample.archive(suggestions: false, drafts: false)), queue: ChangeQueue()
        )
        #expect(ProductPagesOverviewSummary.make(model)?.line == "No pages yet")
        #expect(ProductPagesOverviewSummary.make(model)?.best == nil)
    }

    /// A draft that was pushed comes back under its App Store Connect ID,
    /// and the editor stays on it.
    @Test func aPushedDraftStaysOpenUnderItsNewID() async {
        let services = FakeProductPagesServices()
        let queue = ChangeQueue(changes: Sample.pendingChanges)
        let model = await ProductPagesTestModel.make(services, queue: queue)
        model.open(PageID.privateDiary)
        queue.discard(id: model.builder.newPageChangeID(draftID: PageID.privateDiary))
        services.pushPrivateDiary(.prepareForSubmission)
        await model.load(force: true)
        #expect(model.selectedPageID == PageID.privateDiaryPushed)
        #expect(model.pages.filter { $0.name == "Private diary" }.count == 1)
    }
}
