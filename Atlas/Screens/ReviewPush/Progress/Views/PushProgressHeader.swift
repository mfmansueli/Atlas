//
//  PushProgressHeader.swift
//  Atlas
//

import SwiftUI

/// The top of a push's progress: "Pushing 12 changes and 40 images", how
/// many were sent and how many go at once, one bar for all of it, the time
/// so far and about how long is left, what holds it up (the hourly budget,
/// room at Apple, a cancel), the hourly meter, and each reason something
/// failed with the rows it stopped.
struct PushProgressHeader: View {
    let summary: PushProgressSummary
    let notes: [PushProgressNote]
    let rateLimit: AppStoreConnectRateLimit

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("push.title")
                Text(summary.subtitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .accessibilityIdentifier("push.subtitle")
            }
            ProgressView(value: summary.progress)
                .progressViewStyle(.linear)
                .tint(summary.failedCount > 0 && !summary.isRunning ? Palette.danger : Palette.accent)
                .accessibilityLabel(Text("Push progress"))
                .accessibilityValue(Text(summary.subtitle))
                .accessibilityIdentifier("push.bar")
            if summary.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let time = summary.timeTitle(now: context.date) {
                        Text(time)
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                            .monospacedDigit()
                            .help(Text("From how fast they’ve gone so far: several go at once, and uploads overlap Apple’s processing."))
                            .accessibilityIdentifier("push.time")
                    }
                }
            }
            ForEach(notes) { note in
                Label(note.text, systemImage: note.systemImage)
                    .font(.caption)
                    .foregroundStyle(color(note.tone))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(note.identifier)
            }
            RateLimitMeter(rateLimit: rateLimit)
            PushProgressFailures(groups: summary.failureGroups)
        }
    }

    private func color(_ tone: PushProgressNote.Tone) -> Color {
        switch tone {
        case .secondary: Palette.label2
        case .warning: Palette.warning
        case .danger: Palette.danger
        }
    }
}
