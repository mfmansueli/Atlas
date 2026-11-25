//
//  ScreenshotsPageActionTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Add Screenshots… in the toolbar (board 80): the language page on screen
/// (else the first) with its Add sheet; off while that set is full.
@MainActor
@Suite("Screenshots · page action")
struct ScreenshotsPageActionTests {
    @Test func fromThePreviewItOpensALanguagePageWithItsAddSheet() async {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        #expect(!model.showsLanguagePage)
        #expect(model.pageActionState == .enabled)
        model.startPageAction()
        #expect(model.showsLanguagePage)
        #expect(!model.pageShowsAll)
        #expect(model.handSheet == .add([]))
    }

    @Test func onALanguagePageItAddsToThatLanguage() async {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        model.pageLocale = StoreLocaleCatalog.locale(code: "ja")
        model.displayType = .iPhone
        model.showsLanguagePage = true
        model.startPageAction()
        #expect(model.currentPageLocale.code == "ja")
        #expect(model.handSheet == .add([]))
    }

    @Test func allLanguagesGoesToOne() async {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        model.showsLanguagePage = true
        model.pageShowsAll = true
        model.startPageAction()
        #expect(!model.pageShowsAll)
        #expect(model.handSheet == .add([]))
    }
}
#endif
