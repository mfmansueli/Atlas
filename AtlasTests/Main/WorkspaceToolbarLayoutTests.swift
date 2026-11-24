//
//  WorkspaceToolbarLayoutTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// The workspace toolbar leads with the section's title and status; the
/// actions keep the trailing edge: the title truncates first, then the
/// Autopilot and Review & Push labels fold to their icons, and under 620
/// points the title goes too.
@Suite("WorkspaceToolbarLayout")
struct WorkspaceToolbarLayoutTests {
    /// Labels about as wide as “Suggest Everything” and “Review & Push”.
    private static let labels: [ToolbarRoomItem: CGFloat] = [.autopilotLabel: 131, .reviewLabel: 101]

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
        #expect(!layout.isAutopilotCompact)
        #expect(!layout.isReviewCompact)
    }

    @Test func besideTheSidebarAnOrdinaryWindowKeepsTheLabels() {
        // A 1,100 pt window with the sidebar showing: 836 pt of column,
        // with room left over even with the language picker. The title's
        // 12 pt off the sidebar's edge count too.
        #expect(layout(836).widthForLabels == 684)
        #expect(!layout(836).isCompact)
        var withPicker = Self.labels
        withPicker[.languagePicker] = 121
        #expect(layout(836, room: withPicker).widthForLabels == 813)
        #expect(!layout(836, room: withPicker).isCompact)
        #expect(layout(800, room: withPicker).isCompact)
    }

    @Test func theLabelsFoldOnlyWithoutRoom() {
        #expect(!layout(684).isCompact)
        #expect(layout(683).isCompact)
        // Pro takes room on Free.
        var free = Self.labels
        free[.proButton] = 72
        #expect(layout(700, room: free).isCompact)
        #expect(layout(763, room: free).isCompact)
        #expect(!layout(764, room: free).isCompact)
        // An item that went reports 0 and takes no room.
        free[.proButton] = 0
        #expect(!layout(700, room: free).isCompact)
    }

    @Test func withTheSidebarHiddenTheMinimumWindowFolds() {
        // The window's buttons, the sidebar button and the section menu
        // (“Store Page”, 141 pt) share the toolbar: at the 860 pt minimum
        // the labels fold.
        var room = Self.labels
        room[.sectionMenu] = 141
        let hidden = layout(860, sidebar: false, room: room)
        #expect(hidden.showsTitle)
        #expect(hidden.isAutopilotCompact)
        #expect(hidden.isReviewCompact)
        #expect(layout(860, sidebar: false, room: room).widthForLabels == 949)
        #expect(!layout(949, sidebar: false, room: room).isCompact)
    }

    @Test func under620PointsTheTitleGoesToo() {
        // The minimum window with the sidebar showing: 860 − 256.
        let layout = layout(604)
        #expect(!layout.showsTitle)
        #expect(layout.isCompact)
        #expect(self.layout(620).showsTitle)
    }

    @Test func aReportThatChangesNothingIsntKept() {
        var layout = layout(836)
        let same = layout.report(.autopilotLabel, width: 131.2)
        let wider = layout.report(.autopilotLabel, width: 150)
        let picker = layout.report(.languagePicker, width: 121)
        let gone = layout.report(.languagePicker, width: 0)
        #expect(!same)
        #expect(wider && picker && gone)
        #expect(layout.room[.autopilotLabel] == 150)
        let least = WorkspaceToolbarLayout.minimumTitleWidth
        #expect(abs(layout.widthForLabels - (WorkspaceToolbarLayout.fixedRoom + WorkspaceToolbarLayout.titleInset + least + 150 + 101)) < 0.001)
    }

    /// Alba's Overview: “Alba: Daily Motivation · Version 1.2.2 · Not
    /// submitted yet” wants about 330 pt. In a 980 pt window the labels
    /// fit when the title truncates, so it does, and the actions keep the
    /// trailing edge instead of Review & Push going into “»”.
    @Test func theTitleTruncatesBeforeTheLabelsFold() {
        var room = Self.labels
        room[.title] = 330
        let layout = layout(724, room: room)
        #expect(!layout.isCompact)
        let title = layout.titleRoom ?? 0
        #expect(title == 220)
        #expect(title + WorkspaceToolbarLayout.fixedRoom + WorkspaceToolbarLayout.titleInset + 232 <= 724)
        // Wide, it's capped; folded, the labels' room goes to the title.
        #expect(self.layout(1400, room: room).titleRoom == WorkspaceToolbarLayout.maxTitleWidth)
        let folded = self.layout(560, room: room)
        #expect(folded.isCompact)
        #expect(folded.titleRoom == 560 - WorkspaceToolbarLayout.fixedRoom - WorkspaceToolbarLayout.titleInset)
    }

    @Test func theTitleIsOfferedNoRoomBeforeTheColumnIsMeasured() {
        #expect(WorkspaceToolbarLayout().titleRoom == nil)
    }

    /// The labels fold only once the title is down to its least width,
    /// or its own width when that's narrower.
    @Test func theLabelsFoldOnceTheTitleIsAtItsLeast() {
        var room = Self.labels
        room[.title] = 330
        #expect(layout(684, room: room).widthForLabels == 684)
        #expect(!layout(684, room: room).isCompact)
        #expect(layout(683, room: room).isCompact)
        room[.title] = 100
        #expect(layout(604, room: room).widthForLabels == 604)
    }

    /// Gone under 620 points, the title keeps its room, so the labels
    /// don't unfold as it goes.
    @Test func aTitleThatWentKeepsItsRoom() {
        var room = Self.labels
        room[.title] = 0
        #expect(layout(604, room: room).isCompact)
        #expect(layout(604, room: room).widthForLabels == 684)
    }

    /// A hidden sidebar with the language picker and Pro leaves the
    /// title little; it's never offered less than its least.
    @Test func theTitleIsNeverOfferedLessThanItsLeast() {
        var room = Self.labels
        room[.sectionMenu] = 141
        room[.languagePicker] = 144
        room[.proButton] = 72
        #expect(layout(800, sidebar: false, room: room).titleRoom == WorkspaceToolbarLayout.leastTitleWidth)
        #expect(layout(860, sidebar: false, room: room).titleRoom == 91)
    }

    @Test func aLabelsRoomIsItsWidthBeyondTheIcon() {
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 200.2, folded: 69) == 132)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 0, folded: 69) == nil)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 60, folded: 69) == 0)
    }
}
