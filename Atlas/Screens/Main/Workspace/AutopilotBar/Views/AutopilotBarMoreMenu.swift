//
//  AutopilotBarMoreMenu.swift
//  Atlas
//

import SwiftUI

/// The closed bar's More (board 80): what the toolbar's Autopilot arrow
/// listed before. Reply Automatically's pause while it's on, the run with
/// Show Run… and Cancel Run…, the section's actions without a button,
/// Everything for the app, then the assistant: suggestions it sent, its
/// connection (the status popover) and Settings…. macOS 26 menus: a symbol
/// for the items that have one (README-DS §13).
struct AutopilotBarMoreMenu: View {
    let items: [WorkspaceAutopilotItem]
    var everythingTitle: String?
    var isSuggestingEverything = false
    let state: WorkspaceAutopilotState
    var runProgress: GuidedRunProgress?
    /// Show Run… opens the guided run or the review screenshots.
    var canShowRun = false
    var canCancelRun = false
    /// Reply Automatically's pause, while it's on (board 58).
    var autoReplyPaused: Bool?
    var proposalCount = 0
    /// “Claude Code · Connected”.
    let connectionTitle: String
    let onAction: (WorkspaceAutopilotItem) -> Void
    var onShowRun: () -> Void = {}
    var onCancelRun: () -> Void = {}
    var onPauseAutoReply: (Bool) -> Void = { _ in }
    var onAutoReplySettings: () -> Void = {}
    var onSuggestEverything: () -> Void = {}
    var onReviewProposals: () -> Void = {}
    var onStatus: () -> Void = {}

    var body: some View {
        if let autoReplyPaused {
            Section(autoReplyPaused ? String(localized: "Auto-reply paused") : String(localized: "Replying automatically")) {
                Button(
                    autoReplyPaused ? String(localized: "Resume Auto-Reply") : String(localized: "Pause Auto-Reply"),
                    systemImage: autoReplyPaused ? "play.circle" : "pause.circle"
                ) {
                    onPauseAutoReply(!autoReplyPaused)
                }
                .accessibilityIdentifier("autopilotBar.autoReplyPause")
                Button("Auto-Reply Settings…", systemImage: "gearshape", action: onAutoReplySettings)
            }
        }
        if let text = state.text, !state.isOn, canShowRun || canCancelRun {
            Section(text) {
                if let runProgress { Text(runProgress.line) }
                if canShowRun { Button("Show Run…", systemImage: "eye", action: onShowRun) }
                if canCancelRun {
                    Button("Cancel Run…", systemImage: "xmark.circle", role: .destructive, action: onCancelRun)
                        .accessibilityIdentifier("autopilotBar.cancel")
                }
            }
        }
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Button {
                        onAction(item)
                    } label: {
                        Label {
                            Text(item.isPro ? String(localized: "\(item.title) · Pro") : item.title)
                            if let note = item.note { Text(note) }
                        } icon: {
                            Image(systemName: item.action.systemImage)
                        }
                    }
                    .disabled(!item.isEnabled)
                }
            }
        }
        if let everythingTitle {
            Section {
                Button(isSuggestingEverything ? String(localized: "Show Suggest Everything’s Progress") : everythingTitle, systemImage: "sparkles") {
                    onSuggestEverything()
                }
                .accessibilityIdentifier("autopilotBar.everything")
            }
        }
        Section {
            if proposalCount > 0 {
                Button(
                    proposalCount == 1 ? String(localized: "1 Suggestion to Review…") : String(localized: "\(proposalCount) Suggestions to Review…"),
                    systemImage: "sparkles",
                    action: onReviewProposals
                )
            }
            Button(connectionTitle, action: onStatus)
                .accessibilityIdentifier("autopilotBar.status")
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
        }
    }
}
