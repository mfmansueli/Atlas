//
//  PushProgressFooter.swift
//  Atlas
//

import SwiftUI

/// The bottom of every push's progress. While it runs: Cancel Remaining
/// (what's in flight finishes) and Minimize (Esc) to keep working, the
/// toolbar's Review & Push showing how far it got. Once it's over: Retry
/// Failed, View Results after a price change, and Done.
struct PushProgressFooter: View {
    let summary: PushProgressSummary
    /// Under Done: "Retry sends only the failed ones.", "Live on the App
    /// Store once version 1.4 is released.", or nothing.
    let doneNote: String
    /// Cancel Remaining's help: why it's safe for screenshots.
    let cancelHelp: String?
    let changedPrices: Bool
    let onCancelRemaining: () -> Void
    let onMinimize: () -> Void
    let onRetryFailed: () -> Void
    let onViewResults: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            if summary.isRunning {
                Text("Minimize to keep working: Review & Push in the toolbar shows how far it got.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Spacer()
                Button("Cancel Remaining", action: onCancelRemaining)
                    .disabled(summary.isCancelling)
                    .help(cancelHelp.map { Text($0) } ?? Text("What’s on its way finishes; the rest stays in Review & Push."))
                    .accessibilityIdentifier("push.cancelRemaining")
                Button("Minimize", action: onMinimize)
                    .keyboardShortcut(.cancelAction)
                    .help("Keep working while this runs (Esc)")
                    .accessibilityIdentifier("push.minimize")
            } else {
                Text(doneNote)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Spacer()
                if summary.failedCount > 0 {
                    Button("Retry Failed", action: onRetryFailed)
                        .accessibilityIdentifier("push.retryFailed")
                }
                if changedPrices {
                    Button("View Results", action: onViewResults)
                        .accessibilityIdentifier("push.viewResults")
                }
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("push.done")
            }
        }
        .buttonBorderShape(.capsule)
    }
}
