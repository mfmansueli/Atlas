//
//  PreviewRailCaptionTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The line under the App Store preview's row: the real counts, and
/// "scroll for more" only while some of the row is out of view.
@Suite("PreviewRailCaption")
struct PreviewRailCaptionTests {
    @Test func anAppPreviewAndFiveScreenshotsThatGoOnPastTheEdge() {
        #expect(PreviewRailCaption.text(appPreviews: 1, screenshots: 5, overflows: true) == "App Preview and 5 screenshots · scroll for more")
    }

    @Test func everythingInViewHasNothingToScrollFor() {
        #expect(PreviewRailCaption.text(appPreviews: 1, screenshots: 2, overflows: false) == "App Preview and 2 screenshots")
    }

    @Test func withoutAnAppPreviewItCountsScreenshotsOnly() {
        #expect(PreviewRailCaption.text(appPreviews: 0, screenshots: 5, overflows: true) == "5 screenshots · scroll for more")
        #expect(PreviewRailCaption.text(appPreviews: 0, screenshots: 3, overflows: false) == "3 screenshots")
    }

    @Test func oneScreenshotIsSingular() {
        #expect(PreviewRailCaption.text(appPreviews: 0, screenshots: 1, overflows: false) == "1 screenshot")
        #expect(PreviewRailCaption.text(appPreviews: 1, screenshots: 1, overflows: false) == "App Preview and 1 screenshot")
    }

    @Test func severalAppPreviewsAreCounted() {
        #expect(PreviewRailCaption.counts(appPreviews: 3, screenshots: 10) == "3 App Previews and 10 screenshots")
        #expect(PreviewRailCaption.counts(appPreviews: 2, screenshots: 1) == "2 App Previews and 1 screenshot")
        #expect(PreviewRailCaption.counts(appPreviews: 2, screenshots: 0) == "2 App Previews")
        #expect(PreviewRailCaption.counts(appPreviews: 1, screenshots: 0) == "App Preview")
    }

    @Test func anEmptyRowHasNoLine() {
        #expect(PreviewRailCaption.text(appPreviews: 0, screenshots: 0, overflows: true) == nil)
    }
}
