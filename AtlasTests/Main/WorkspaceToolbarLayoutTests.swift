//
//  WorkspaceToolbarLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The workspace toolbar leads with the section's title and status; at 860
/// points the Autopilot and Review & Push labels fold to their icons, and
/// under 620 points the title goes too.
@Suite("WorkspaceToolbarLayout")
struct WorkspaceToolbarLayoutTests {
    @Test func nothingFoldsBeforeTheColumnIsMeasured() {
        let layout = WorkspaceToolbarLayout()
        #expect(!layout.isCompact)
        #expect(!layout.isReviewCompact)
        #expect(layout.showsTitle)
    }

    @Test func aWideColumnShowsEveryLabel() {
        let layout = WorkspaceToolbarLayout(detailWidth: 944)
        #expect(layout.showsTitle)
        #expect(!layout.isAutopilotCompact)
        #expect(!layout.isReviewCompact)
    }

    @Test func at860PointsTheLabelsFoldAndTheTitleStays() {
        // The minimum window with the sidebar hidden.
        let layout = WorkspaceToolbarLayout(detailWidth: 860)
        #expect(layout.showsTitle)
        #expect(layout.isAutopilotCompact)
        #expect(layout.isReviewCompact)
    }

    @Test func under620PointsTheTitleGoesToo() {
        // The minimum window with the sidebar showing: 860 − 256.
        let layout = WorkspaceToolbarLayout(detailWidth: 604)
        #expect(!layout.showsTitle)
        #expect(layout.isCompact)
        #expect(WorkspaceToolbarLayout(detailWidth: 620).showsTitle)
        #expect(!WorkspaceToolbarLayout(detailWidth: 861).isCompact)
        #expect(WorkspaceToolbarLayout(detailWidth: 860).isCompact)
    }
}
