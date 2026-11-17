//
//  WorkspaceToolbarLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The workspace toolbar with the sections in the sidebar: it only holds
/// actions; the app's title shows while the sidebar is hidden and there's
/// room, and Review & Push keeps its label down to 720 points.
@Suite("WorkspaceToolbarLayout")
struct WorkspaceToolbarLayoutTests {
    @Test func nothingFoldsBeforeTheColumnIsMeasured() {
        let layout = WorkspaceToolbarLayout()
        #expect(!layout.isCompact)
        #expect(!layout.isReviewCompact)
    }

    @Test func theTitleShowsOnlyWhileTheSidebarIsHidden() {
        let layout = WorkspaceToolbarLayout(detailWidth: 944)
        #expect(!layout.showsTitle(isSidebarShown: true))
        #expect(layout.showsTitle(isSidebarShown: false))
    }

    @Test func atTheMinimumWindowWithoutTheSidebarEverythingFits() {
        // 860 points wide, the sidebar hidden: the section menu, the title
        // and Review & Push with its label.
        let layout = WorkspaceToolbarLayout(detailWidth: 860)
        #expect(layout.showsTitle(isSidebarShown: false))
        #expect(!layout.isReviewCompact)
    }

    @Test func under720PointsTheTitleGoesAndReviewAndPushKeepsItsCount() {
        // The minimum window with the sidebar showing: 860 − 256.
        let layout = WorkspaceToolbarLayout(detailWidth: 604)
        #expect(layout.isCompact)
        #expect(layout.isReviewCompact)
        #expect(!layout.showsTitle(isSidebarShown: false))
        #expect(!WorkspaceToolbarLayout(detailWidth: 720).isCompact)
        #expect(WorkspaceToolbarLayout(detailWidth: 719).isCompact)
    }
}
