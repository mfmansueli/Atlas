//
//  WorkspaceToolbarLayoutTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// The workspace toolbar leads with the section's title and status; the
/// Autopilot and Review & Push labels fold to their icons only when the
/// toolbar has no room for them, and under 620 points the title goes too.
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
        // with room left over even with the language picker.
        #expect(layout(836).widthForLabels == 672)
        #expect(!layout(836).isCompact)
        var withPicker = Self.labels
        withPicker[.languagePicker] = 121
        #expect(layout(836, room: withPicker).widthForLabels == 801)
        #expect(!layout(836, room: withPicker).isCompact)
        #expect(layout(800, room: withPicker).isCompact)
    }

    @Test func theLabelsFoldOnlyWithoutRoom() {
        #expect(!layout(672).isCompact)
        #expect(layout(671).isCompact)
        // Pro takes room on Free.
        var free = Self.labels
        free[.proButton] = 72
        #expect(layout(700, room: free).isCompact)
        #expect(!layout(752, room: free).isCompact)
        // An item that went reports 0 and takes no room.
        free[.proButton] = 0
        #expect(!layout(700, room: free).isCompact)
    }

    @Test func withTheSidebarHiddenTheMinimumWindowFolds() {
        // The window's buttons, the sidebar button and the section menu
        // share the toolbar: at the 860 pt minimum the labels fold.
        let hidden = layout(860, sidebar: false)
        #expect(hidden.showsTitle)
        #expect(hidden.isAutopilotCompact)
        #expect(hidden.isReviewCompact)
        #expect(!layout(944, sidebar: false).isCompact)
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
        #expect(abs(layout.widthForLabels - (WorkspaceToolbarLayout.fixedRoom + 150 + 101)) < 0.001)
    }

    @Test func aLabelsRoomIsItsWidthBeyondTheIcon() {
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 200.2, folded: 69) == 132)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 0, folded: 69) == nil)
        #expect(ToolbarLabelRoom<EmptyView, EmptyView>.extra(full: 60, folded: 69) == 0)
    }
}
