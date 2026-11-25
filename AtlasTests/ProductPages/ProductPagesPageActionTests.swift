//
//  ProductPagesPageActionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// New Page… in the toolbar (board 80): on in the list once the pages are
/// read, gone in a page's editor, and it opens New Page's sheet.
@MainActor
@Suite("Custom Product Pages · page action")
struct ProductPagesPageActionTests {
    @Test func beforeTheReadItsOff() {
        let model = ProductPagesViewModel(
            app: DebugFixtures.lumen, services: FakeProductPagesServices(), store: ProductPagesStore(), queue: ChangeQueue()
        )
        #expect(model.pageActionState == .disabled(reason: nil))
        model.startPageAction()
        #expect(!model.isNewPagePresented)
    }

    @Test func theListHasItAndItOpensTheSheet() async {
        let model = await ProductPagesTestModel.make()
        #expect(model.pageActionState == .enabled)
        model.startPageAction()
        #expect(model.isNewPagePresented)
    }

    @Test func aPagesEditorHidesIt() async throws {
        let model = await ProductPagesTestModel.make()
        let page = try #require(model.pages.first)
        model.open(page.id)
        #expect(model.pageActionState == .hidden)
        model.startPageAction()
        #expect(!model.isNewPagePresented)
    }
}
