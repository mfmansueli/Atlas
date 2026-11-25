//
//  WorkspaceBottomBar.swift
//  Atlas
//

import SwiftUI

/// The bottom of every section (board 80): the Autopilot bar and, beside
/// it, aligned at the bottom, what the person sends (Review & Push). Both
/// float over the page, which leaves the closed bar its room
/// (`AutopilotBarRoom`); the open bar grows up over the page.
struct WorkspaceBottomBar<Bar: View, Trailing: View>: View {
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.small) {
            bar()
                .frame(maxWidth: Metrics.autopilotBarWidth)
            trailing()
                .fixedSize()
        }
        .frame(maxWidth: Metrics.autopilotDockWidth)
        .padding(.horizontal, AutopilotBarRoom.sideInset)
        .padding(.bottom, AutopilotBarRoom.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
