//
//  WorkspaceBottomBar.swift
//  Atlas
//

import SwiftUI

/// The bottom of every section (board 80): the Autopilot bar and, beside
/// it, centred on the bar's field, what the person sends (Review & Push). Both
/// float over the page, which leaves the closed bar its room
/// (`AutopilotBarRoom`); the open bar grows up over the page.
struct WorkspaceBottomBar<Bar: View, Trailing: View>: View {
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.small) {
            bar()
                .frame(maxWidth: Metrics.autopilotBarWidth)
            // As tall as the closed field and at the foot of the bar, so
            // Review & Push stays centred on the field as the bar grows up.
            trailing()
                .fixedSize()
                .frame(height: Metrics.autopilotBarFieldHeight)
        }
        .frame(maxWidth: Metrics.autopilotDockWidth)
        .padding(.horizontal, AutopilotBarRoom.sideInset)
        .padding(.bottom, AutopilotBarRoom.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
