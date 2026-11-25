//
//  StoreArtworkRulesTests.swift
//  AtlasTests
//

#if DEBUG
import CoreGraphics
import Testing
@testable import Atlas

/// Board 78's narrow-width rules and the In search mark.
@Suite("Store artwork rules")
struct StoreArtworkRulesTests {
    @Test func thePreviewLeavesTheScreenshotsPageUnder900() {
        #expect(!StoreArtworkRules.showsPreview(pageWidth: 860))
        #expect(!StoreArtworkRules.showsPreview(pageWidth: 899.5))
        #expect(StoreArtworkRules.showsPreview(pageWidth: 900))
        #expect(StoreArtworkRules.showsPreview(pageWidth: 1280))
    }

    @Test func headerAndSearchStackWhenTheyDontFitSideBySide() {
        // 360 + 12 + 231 = 603.
        #expect(StoreArtworkRules.stacksArtwork(columnWidth: 602))
        #expect(!StoreArtworkRules.stacksArtwork(columnWidth: 603))
        #expect(!StoreArtworkRules.stacksArtwork(columnWidth: 800))
    }

    @Test func screenshotsOneToThreeOnIPhoneAreInSearch() {
        #expect((0..<5).map { StoreArtworkRules.marksInSearch(keptIndex: $0, display: .iPhone) } == [true, true, true, false, false])
        #expect(!StoreArtworkRules.marksInSearch(keptIndex: nil, display: .iPhone), "A deleted one isn't")
        #expect(!StoreArtworkRules.marksInSearch(keptIndex: 0, display: .iPad))
        #expect(!StoreArtworkRules.marksInSearch(keptIndex: 0, display: .mac))
    }
}
#endif
