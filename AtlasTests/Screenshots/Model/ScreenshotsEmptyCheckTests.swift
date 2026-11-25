//
//  ScreenshotsEmptyCheckTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Board 74 · 4: Screenshots is empty only with nothing on the App Store,
/// no capture and nothing added by hand.
@Suite("ScreenshotsEmptyCheck")
struct ScreenshotsEmptyCheckTests {
    @Test func nothingAnywhereIsEmpty() {
        let document = ScreenshotsDebugDocuments.document(for: .noCaptures)
        #expect(ScreenshotsEmptyCheck.isEmpty(live: LiveScreenshots(), document: document))
    }

    @Test func beforeTheDocumentIsReadItIsntEmptyYet() {
        #expect(!ScreenshotsEmptyCheck.isEmpty(live: LiveScreenshots(), document: nil))
    }

    @Test func screenshotsOnTheAppStoreAreSomething() {
        let document = ScreenshotsDebugDocuments.document(for: .noCaptures)
        #expect(!ScreenshotsEmptyCheck.isEmpty(live: ScreenshotsDebugDocuments.live, document: document))
    }

    @Test func liveSetsWithoutAScreenshotStillCountAsEmpty() {
        let document = ScreenshotsDebugDocuments.document(for: .noCaptures)
        var live = ScreenshotsDebugDocuments.live
        live.screenshotSets = live.screenshotSets.map { set in
            var empty = set
            empty.screenshots = []
            return empty
        }
        live.previewSets = []
        #expect(ScreenshotsEmptyCheck.isEmpty(live: live, document: document))
    }

    @Test func capturesAreSomething() {
        let document = ScreenshotsDebugDocuments.document(for: .standard)
        #expect(!document.captures.isEmpty)
        #expect(!ScreenshotsEmptyCheck.isEmpty(live: LiveScreenshots(), document: document))
    }
}
#endif
