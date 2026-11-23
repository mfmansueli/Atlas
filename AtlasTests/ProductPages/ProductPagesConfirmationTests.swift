//
//  ProductPagesConfirmationTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 55: what Hide, Delete, Discard and moving a keyword say first, and
/// what agreeing does.
@MainActor
@Suite("Custom Product Pages confirmations")
struct ProductPagesConfirmationTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    @Test func hidingSaysTheLinkKeepsWorkingAndQueuesVisibleOff() async throws {
        let model = await ProductPagesTestModel.make()
        model.open(PageID.prompts)
        model.setVisible(false)
        let confirmation = try #require(model.confirmation)
        #expect(confirmation == .hide(pageID: PageID.prompts))
        #expect(model.confirmationTitle(confirmation) == "Hide “Prompts”?")
        #expect(model.confirmationMessage(confirmation).hasPrefix("Its link and keywords lead to the default page."))
        #expect(model.confirmationButton(confirmation) == "Hide Page")
        #expect(!model.isDestructive(confirmation))
        model.confirm(confirmation)
        #expect(model.confirmation == nil)
        #expect(try model.edits(of: ProductPagesTestModel.page(model, PageID.prompts)).isVisible == false)
    }

    @Test func deletingAPageInAppStoreConnectWaitsForThePush() async {
        let model = await ProductPagesTestModel.make()
        let confirmation = ProductPageConfirmation.delete(pageID: PageID.year)
        #expect(model.confirmationTitle(confirmation) == "Delete “Year in review”?")
        #expect(model.confirmationMessage(confirmation).hasSuffix("This can’t be undone once pushed."))
        #expect(model.isDestructive(confirmation))
        model.confirm(confirmation)
        #expect(model.page(PageID.year) == nil)
        #expect(model.queue.changes(for: Sample.appID, section: .productPages).contains { $0.id.hasSuffix("\(PageID.year).delete") })
        model.undoLast()
        #expect(model.page(PageID.year) != nil)
    }

    @Test func deletingADraftIsAtOnce() async {
        let model = await ProductPagesTestModel.make()
        let confirmation = ProductPageConfirmation.delete(pageID: PageID.privateDiary)
        #expect(model.confirmationMessage(confirmation).hasPrefix("Only in Atlas, with its suggestions and changes."))
        model.confirm(confirmation)
        #expect(model.page(PageID.privateDiary) == nil)
        #expect(model.queue.changes(for: Sample.appID, section: .productPages).isEmpty)
    }

    @Test func discardingSaysWhatIsUndone() async throws {
        let model = await ProductPagesTestModel.make()
        let prompts = try ProductPagesTestModel.page(model, PageID.prompts)
        let builder = model.builder
        model.queue.upsert(contentsOf: [
            builder.textChange("Start with one line.", locale: "en-US", of: prompts, source: .you),
            builder.keywordsChange(["journal", "prompts", "daily", "reflection"], locale: "en-US", of: prompts, source: .you),
        ].compactMap(\.self))
        let confirmation = ProductPageConfirmation.discard(pageID: PageID.prompts)
        #expect(model.confirmationTitle(confirmation) == "Discard 2 changes to “Prompts”?")
        #expect(model.confirmationMessage(confirmation)
            == "The page goes back to what is in App Store Connect: 1 promotional text and 1 keyword are undone.")
        #expect(model.confirmationButton(confirmation) == "Discard Changes")
        model.confirm(confirmation)
        #expect(model.pendingCount(of: prompts) == 0)

        model.queue.upsert(contentsOf: [builder.deepLinkChange("https://lumen.app/prompts/week", of: prompts, source: .you)].compactMap(\.self))
        #expect(model.confirmationTitle(confirmation) == "Discard 1 change to “Prompts”?")
        #expect(model.confirmationMessage(confirmation) == "The page goes back to what is in App Store Connect: the deep link is undone.")
    }

    /// A draft's own creation isn't one of its changes.
    @Test func discardingADraftKeepsIt() async {
        let model = await ProductPagesTestModel.make()
        model.confirm(.discard(pageID: PageID.privateDiary))
        #expect(model.page(PageID.privateDiary) != nil)
        #expect(model.queue.changes(for: Sample.appID, section: .productPages).count == 1)
    }

    @Test func movingAKeywordSaysWhichPageLosesIt() async {
        let model = await ProductPagesTestModel.make()
        let confirmation = ProductPageConfirmation.moveKeyword("journal", locale: "en-US", fromPageID: PageID.prompts, fromName: "Prompts")
        #expect(model.confirmationTitle(confirmation) == "Move “journal” to this page?")
        #expect(model.confirmationMessage(confirmation).contains("“Prompts” loses it once this one is visible"))
        #expect(model.confirmationButton(confirmation) == "Move Keyword")
    }
}
