//
//  ActivityRow.swift
//  Atlas
//

import SwiftUI

/// One push in Activity (README-DS §15): what changed, the app, when and
/// how many; "All succeeded" in green or "1 failed" in amber with each
/// reason in Atlas's words (Apple's text under Details); and its row
/// actions, neutral: Results after a price change, Restore Previous Values
/// or, for screenshots, Restore Previous Screenshots…. The push that just
/// ended has the accent's tint behind it, with no animation.
struct ActivityRow: View {
    let record: PushRecord
    /// The push "Show in Activity" came for.
    var isHighlighted = false
    var now = Date.now
    let onResults: () -> Void
    let onRestore: () -> Void
    var onRestoreScreenshots: (() -> Void)?

    var body: some View {
        let text = ActivityText(now: now)
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(record.title)
                    .atlasTextStyle(.headline)
                    .lineLimit(2)
                Text(text.details(of: record))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                if let screenshots = record.screenshots {
                    ScreenshotActivityDetails(summary: screenshots)
                }
                outcome
                    .padding(.top, Spacing.xxSmall)
                ForEach(record.failedChanges) { change in
                    ErrorCopyMessage(copy: ActivityText.failure(of: change, in: record))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
        .background(isHighlighted ? Palette.accentTint : .clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(text.accessibilityLabel(of: record)))
        .accessibilityIdentifier(isHighlighted ? "activity.record.highlighted" : "activity.record.\(record.id.uuidString)")
    }

    /// Green when everything went, amber when something didn't: state.
    @ViewBuilder
    private var outcome: some View {
        if record.failedCount > 0 {
            Pill(text: ActivityText.failed(record.failedCount), systemImage: "exclamationmark.triangle.fill", style: .warning)
        } else {
            Pill(text: ActivityText.allSucceeded, systemImage: "checkmark", style: .ok)
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.small) {
            if record.changedPrices {
                Button(String(localized: "Results", comment: "kind:button · a price push in Activity"), action: onResults)
                    .accessibilityIdentifier("activity.results")
            }
            if let screenshots = record.screenshots {
                Button {
                    onRestoreScreenshots?()
                } label: {
                    Label(
                        String(localized: "Restore Previous Screenshots…", comment: "kind:button · a screenshot push in Activity"),
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .disabled(onRestoreScreenshots == nil || screenshots.locales.isEmpty)
                .help(String(localized: "Puts this locale’s earlier screenshots in Review & Push. Nothing is pushed.", comment: "kind:tooltip"))
                .accessibilityIdentifier("activity.restoreScreenshots")
            }
            if record.screenshots == nil || !record.pushed.isEmpty {
                restoreValuesButton
            }
        }
        // Row actions, neutral (README-DS §4): repeated on every push.
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .lineLimit(1)
    }

    private var restoreValuesButton: some View {
        let canRestore = !record.restoringChanges().isEmpty
        return Button(action: onRestore) {
            Label(String(localized: "Restore Previous Values", comment: "kind:button · a push in Activity"), systemImage: "arrow.uturn.backward")
        }
        .disabled(!canRestore)
        .help(canRestore
            ? String(localized: "Puts the values from before this push in Review & Push. Nothing is pushed.", comment: "kind:tooltip")
            : String(localized: "These values can’t be restored from here.", comment: "kind:tooltip"))
        .accessibilityIdentifier("activity.restore")
    }
}
