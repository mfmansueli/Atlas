//
//  AutopilotBarActionButton.swift
//  Atlas
//

import SwiftUI

/// One of the two actions beside the closed bar's field (board 80): it
/// starts AI work, so it's never filled: the Toolbar button (README —
/// Design system §4), native Liquid Glass like More and Review & Push
/// beside it, with a purple label. A click sends the request like a
/// message. On Free, an action that's part of Pro carries PRO and opens
/// the paywall.
struct AutopilotBarActionButton: View {
    let item: WorkspaceAutopilotItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxSmall) {
                Text(item.action.shortTitle(fullTitle: item.title))
                    .foregroundStyle(Palette.ai)
                    .lineLimit(1)
                if item.isPro { ProChip() }
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .fixedSize()
        .disabled(!item.isEnabled)
        .help(Text("\(item.action.subtitle ?? item.title) · sends it to Autopilot", comment: "kind:tooltip · an action beside the Autopilot bar's field"))
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier("autopilotBar.action")
    }
}
