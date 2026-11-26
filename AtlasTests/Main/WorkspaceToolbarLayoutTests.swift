//
//  WorkspaceToolbarLayoutTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// The workspace toolbar leads with the section's title and status; the
/// actions keep the trailing edge: the title truncates first, then the
/// Review & Push label folds to its icon, and under 620 points the title
/// goes too. Autopilot is the bar at the bottom of the section (board 80).
@Suite("WorkspaceToolbarLayout")
struct WorkspaceToolbarLayoutTests {
    /// A label about as wide as “Review & Push”.
    private static let labels: [ToolbarRoomItem: CGFloat] = [.reviewLabel: 101]

    private func layout(_ width: CGFloat, sidebar: Bool = true, room: [ToolbarRoomItem: CGFloat] = labels) -> WorkspaceToolbarLayout {
        WorkspaceToolbarLayout(detailWidth: width, isSidebarShown: sidebar, room: room)
    }

    @Test func nothingFoldsBeforeTheColumnIsMeasured() {
        let layout = WorkspaceToolbarLayout()
        #expect(!layout.isCompact)
        #expect(!layout.isReviewCompact)
        #expect(layout.showsTitle)
    }

    @Test func aWideColumnShowsEveryLabel() {
        let layout = layout(944)
        #expect(layout.showsTitle)
        #expect(!layout.isReviewCompact)
    }

    @Test func besideTheSidebarAnOrdinaryWindowKeepsTheLabels() {
        // A 1,100 pt window with the sidebar showing: 836 pt of column,
        // with room left over even with an item of its own as wide as 121
        // pt. The title's 12 pt off the sidebar's edge count too.
        #expect(layout(836).widthForLabels == 476)
        #expect(!layout(836).isCompact)
        var withItem = Self.labels
        withItem[.proButton] = 121
        #expect(layout(836, room: withItem).widthForLabels == 605)
        #expect(!layout(836, room: withItem).isCompact)
        #expect(layout(600, room: withItem).isCompact)
    }

    @Test func theLabelsFoldOnlyWithoutRoom() {
        #expect(!layout(476).isCompact)
        #expect(layout(475).isCompact)
        // Pro takes room on Free.
        var free = Self.labels
        free[.proButton] = 72
        #expect(layout(500, room: free).isCompact)
        #expect(layout(555, room: free).isCompact)
        #expect(!layout(556, room: free).isCompact)
        // An item that went reports 0 and takes no room.
        free[.proButton] = 0
        #expect(!layout(500, room: free).isCompact)
    }

    @Test func withTheSidebarHiddenTheMinimumWindowKeepsTheLabel() {
        // The window's buttons, the sidebar button and the section menu
        // (“Store Page”, 141 pt) share the toolbar: without Autopilot in
        // it, the 860 pt minimum keeps Review & Push's label.
        var room = Self.labels
        room[.sectionMenu] = 141
        let hidden = layout(860, sidebar: false, room: room)
        #expect(hidden.showsTitle)
        #expect(!hidden.isReviewCompact)
        #expect(hidden.widthForLabels == 741)
        #expect(layout(740, sidebar: false, room: room).isCompact)
    }

    @Test func under620PointsTheTitleGoesToo() {
        // The minimum window with the sidebar showing: 860 − 256.
        let layout = layout(604)
        #expect(!layout.showsTitle)
        #expect(!layout.isCompact)
        #expect(self.layout(620).showsTitle)
    }

    @Test func aReportThatChangesNothingIsntKept() {
        var layout = layout(836)
        let same = layout.report(.reviewLabel, width: 101.2)
        let wider = layout.report(.reviewLabel, width: 150)
        let pro = layout.report(.proButton, width: 72)
        let gone = layout.report(.proButton, width: 0)
        #expect(!same)
        #expect(wider && pro && gone)
        #expect(layout.room[.reviewLabel] == 150)
        let least = WorkspaceToolbarLayout.minimumTitleWidth
        #expect(abs(layout.widthForLabels - (WorkspaceToolbarLayout.fixedRoom + WorkspaceToolbarLayout.titleInset + least + 150)) < 0.001)
    }

    /// Alba's Overview: “Alba: Daily Motivation · Version 1.2.2 · Not
    /// submitted yet” wants about 330 pt. In a narrow column the label
    /// fits when the title truncates, so it does, and the actions keep the
    /// trailing edge instead of Review & Push going into “»”.
    @Test func theTitleTruncatesBeforeTheLabelsFold() {
        var room = Self.labels
        room[.title] = 330
        let layout = layout(516, room: room)
        #expect(!layout.isCompact)
        let title = layout.titleRoom ?? 0
        #expect(title == 220)
        #expect(title + WorkspaceToolbarLayout.fixedRoom + WorkspaceToolbarLayout.titleInset + 101 <= 516)
        // Wide, it's capped; folded, the labels' room goes to the title.
        #expect(self.layout(1400, room: room).titleRoom == WorkspaceToolbarLayout.maxTitleWidth)
        let folded = self.layout(400, room: room)
        #expect(folded.isCompact)
        #expect(folded.titleRoom == 400 - WorkspaceToolbarLayout.fixedRoom - WorkspaceToolbarLayout.titleInset)
    }

    @Test func theTitleIsOfferedNoRoomBeforeTheColumnIsMeasured() {
        #expect(WorkspaceToolbarLayout().titleRoom == nil)
    }

    /// The labels fold only once the title is down to its least width,
    /// or its own width when that's narrower.
    @Test func theLabelsFoldOnceTheTitleIsAtItsLeast() {
        var room = Self.labels
        room[.title] = 330
        #expect(layout(476, room: room).widthForLabels == 476)
        #expect(!layout(476, room: room).isCompact)
        #expect(layout(475, room: room).isCompact)
        room[.title] = 100
        #expect(layout(396, room: room).widthForLabels == 396)
    }

    /// Gone under 620 points, the title keeps its room, so the labels
    /// don't unfold as it goes.
    @Test func aTitleThatWentKeepsItsRoom() {
        var room = Self.labels
        room[.title] = 0
        #expect(layout(470, room: room).isCompact)
        #expect(layout(470, room: room).widthForLabels == 476)
    }

    /// A hidden sidebar with Pro leaves the title little; it's never
    /// offered less than its least.
    @Test func theTitleIsNeverOfferedLessThanItsLeast() {
        var room = Self.labels
        room[.sectionMenu] = 141
        room[.proButton] = 72
        // Folded: 183 fixed + 136 + 141 lead + 72 + 8 for Pro = 540.
        #expect(layout(583, sidebar: false, room: room).titleRoom == WorkspaceToolbarLayout.leastTitleWidth)
        #expect(layout(631, sidebar: false, room: room).titleRoom == 91)
    }

    @Test func aLabelsRoomIsItsWidthBeyondTheIcon() {
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 200.2, folded: 69) == 132)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 0, folded: 69) == nil)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 60, folded: 69) == 0)
    }
}
