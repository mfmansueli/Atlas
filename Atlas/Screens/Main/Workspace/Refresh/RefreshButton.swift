//
//  RefreshButton.swift
//  Atlas
//

import SwiftUI

/// Refresh (README-DS §15, board 90): an icon-only toolbar button, in the
/// sidebar's top row left of Hide Sidebar, or in the toolbar after the
/// section menu while the sidebar is hidden. It takes the toolbar's own
/// button style, so its glass is the same 36 pt circle as Hide Sidebar's:
/// no size of its own (a borderless 28 pt frame drew a narrower pill). Clicking it (or ⌘R) reads App
/// Store Connect again. While it reads the arrow turns (the system's
/// rotate effect) and the button is off, so a second click does nothing;
/// with Reduce Motion it doesn't turn, it dims, and the tooltip and
/// VoiceOver say "Updating". The last update's time is in the tooltip and
/// VoiceOver only. An amber dot says the last refresh failed and a grey
/// one that there's no network; the toolbar's status line explains them.
struct RefreshButton: View {
    /// `sidebar.refresh` or `workspace.refreshButton`, for the UI tests.
    let identifier: String

    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The tooltip's "2 minutes ago" follows the clock.
        TimelineView(.everyMinute) { context in
            let state = navigator.refreshState
            let text = RefreshText(now: context.date)
            Button {
                navigator.refresh()
            } label: {
                // The name shows only in the toolbar's overflow menu.
                Label {
                    Text("Refresh", comment: "kind:accessibility-label · the sidebar's Refresh button")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, isActive: state.isRefreshing && !reduceMotion)
                        .overlay(alignment: .topTrailing) { dot(for: state) }
                }
                .labelStyle(.iconOnly)
            }
            .disabled(state.isRefreshing)
            .help(text.tooltip(state))
            .accessibilityLabel(Text(text.accessibilityLabel(state)))
            .accessibilityIdentifier(identifier)
        }
    }

    /// Amber after a failure, grey offline; nothing otherwise. Never blue
    /// or purple: it's state.
    @ViewBuilder
    private func dot(for state: RefreshState) -> some View {
        if let color = Self.dotColor(for: state) {
            Circle()
                .fill(color)
                .frame(width: Metrics.refreshDotSize, height: Metrics.refreshDotSize)
                .accessibilityHidden(true)
        }
    }

    static func dotColor(for state: RefreshState) -> Color? {
        switch state {
        case .failed: Palette.warn
        case .offline: Palette.label2
        case .idle, .refreshing, .updated, .readOnly: nil
        }
    }
}
