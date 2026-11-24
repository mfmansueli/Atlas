//
//  OverviewAfterReleaseRowTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Overview's "After release": Analytics, Ratings & Reviews and
/// Product Pages, one line each (README — redesign, November 22).
@Suite("Overview After release rows")
struct OverviewAfterReleaseRowTests {
    @Test func analyticsSaysWhereSetupStands() {
        let off = OverviewAfterReleaseRow.analytics(setup: .off, report: nil, newFindings: 0)
        #expect(off.section == .analytics)
        #expect(off.detail == "Not turned on · see where people drop off before paying")
        #expect(off.accessibilityText == "Open Analytics")
        #expect(OverviewAfterReleaseRow.analytics(setup: .keyCannotAsk, report: nil, newFindings: 0).detail
            == "Needs an Admin key to ask Apple for reports")
        #expect(OverviewAfterReleaseRow.analytics(setup: .ready, report: nil, newFindings: 0).detail == "No numbers yet")
    }

    /// New findings are counted in grey, not purple: they're to read, not
    /// to accept.
    @Test func findingsAreAGreyCount() {
        let row = OverviewAfterReleaseRow.analytics(setup: .ready, report: nil, newFindings: 3)
        #expect(row.count == 3)
        #expect(!row.countsSuggestions)
        #expect(row.accessibilityText == "Open Analytics, 3 new findings")
    }

    @Test func reviewsSayWhatNeedsAReply() {
        let unread = OverviewAfterReleaseRow.reviews(archive: ReviewsArchive(), isPro: true)
        #expect(unread.title == "Ratings & Reviews")
        #expect(unread.detail == "Not read yet")
        var archive = ReviewsArchive()
        archive.fetchedAt = Date()
        let read = OverviewAfterReleaseRow.reviews(archive: archive, isPro: true)
        #expect(read.detail == "Every review that needs a reply has one")
        #expect(read.count == 0)
    }

    @Test func productPagesUseTheSectionsLine() {
        #expect(OverviewAfterReleaseRow.productPages(nil).detail == "Not read yet")
        let summary = ProductPagesOverviewSummary(line: "6 pages · 3 visible on the App Store · 1 rejected", suggestionCount: 4)
        let row = OverviewAfterReleaseRow.productPages(summary)
        #expect(row.detail == "6 pages · 3 visible on the App Store · 1 rejected")
        #expect(row.count == 4)
        #expect(row.countsSuggestions)
        #expect(row.accessibilityText == "Open Custom Product Pages, 4 suggestions to review")
    }
}
