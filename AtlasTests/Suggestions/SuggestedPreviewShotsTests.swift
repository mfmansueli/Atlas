//
//  SuggestedPreviewShotsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Store Page's App Store preview with Suggested on: the screenshots
/// whose captions Claude Code suggested (German's 2, 3 and 5 in the sample
/// document), drawn with them on the iPhone set the row shows.
@MainActor
@Suite("Suggested preview shots")
struct SuggestedPreviewShotsTests {
    private let engine = ScreenshotLayoutEngine(catalog: ScreenshotsTestFixtures.fonts)

    private func shots(
        _ locale: StoreLocale,
        document: ScreenshotsDocument? = ScreenshotsDebugDocuments.standard,
        live: LiveScreenshots = ScreenshotsDebugDocuments.live
    ) -> SuggestedPreviewShots {
        SuggestedPreviewShots.make(document: document, live: live, locale: locale, primary: .englishUS, engine: engine)
    }

    @Test func germanShowsItsThreeSuggestedCaptionsOnTheIPhoneSet() {
        let german = shots(.german)
        #expect(german.locale == "de-DE")
        #expect(german.displayType == .iPhone)
        #expect(Set(german.previews.keys) == [1, 2, 4])
        #expect(german.preview(at: 0) == nil)
        #expect(german.preview(at: 1)?.layout.lines.map(\.text).joined(separator: " ").contains("Blick") == true)
        #expect(german.accessibilityText == "3 captions suggested")
    }

    @Test func aLanguageWithNothingSuggestedShowsTheLiveImages() {
        let english = shots(.englishUS)
        #expect(english.previews.isEmpty)
        #expect(english.accessibilityText == nil)
    }

    @Test func aLanguageWithoutItsOwnSetShowsThePrimarysSuggestions() {
        var live = ScreenshotsDebugDocuments.live
        live.screenshotSets.removeAll { $0.locale == "de-DE" }
        let german = shots(.german, live: live)
        #expect(german.locale == "en-US")
        #expect(german.previews.isEmpty, "Nothing is suggested for English (U.S.)")
    }

    @Test func noTemplateOrDocumentDrawsNothing() {
        var bare = ScreenshotsDebugDocuments.standard
        bare.history = nil
        #expect(shots(.german, document: bare) == .none)
        #expect(shots(.german, document: nil) == .none)
        #expect(shots(.german, live: LiveScreenshots(screenshotSets: [], previewSets: [])) == .none)
    }

    @Test func neverMoreThanTheSetHasScreenshots() {
        var live = ScreenshotsDebugDocuments.live
        if let index = live.screenshotSets.firstIndex(where: { $0.locale == "de-DE" && $0.displayType == .iPhone }) {
            live.screenshotSets[index].screenshots = Array(live.screenshotSets[index].screenshots.prefix(2))
        }
        let german = shots(.german, live: live)
        #expect(Set(german.previews.keys) == [1])
        #expect(german.accessibilityText == "1 caption suggested")
    }
}
#endif
