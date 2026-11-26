//
//  RefreshStatusLine.swift
//  Atlas
//

import SwiftUI

/// The end of the toolbar's status line when the last Refresh didn't go
/// well (README-DS §15): an amber triangle, "Couldn’t update" and
/// Details…, which opens the error; "Offline · from 14:32"; a lock and
/// "View only · updated 2 min ago". Nothing when all is well: the time
/// of the last update is only in Refresh's tooltip.
struct RefreshStatusLine: View {
    let state: RefreshState
    /// Details…: the error sheet.
    let onDetails: () -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let line = RefreshText(now: context.date).statusLine(state) {
                HStack(spacing: Spacing.xxSmall) {
                    if let symbol = Self.symbol(for: state) {
                        Image(systemName: symbol)
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                    }
                    Text(line)
                        .foregroundStyle(color)
                    if case .failed = state {
                        Button(String(localized: "Details…", comment: "kind:button · the status line's Couldn’t update"), action: onDetails)
                            .plainButton()
                            .accessibilityIdentifier("refresh.details")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("refresh.status")
            }
        }
    }

    /// Amber after a failure; the rest is grey: state, never blue or purple.
    private var color: Color {
        if case .failed = state { return Palette.warn }
        return Palette.label2
    }

    static func symbol(for state: RefreshState) -> String? {
        switch state {
        case .failed: "exclamationmark.triangle.fill"
        case .readOnly: "lock.fill"
        case .idle, .refreshing, .updated, .offline: nil
        }
    }
}
