//
//  AssistantChatStepsList.swift
//  Atlas
//

import SwiftUI

/// The steps of the answer being worked on, counted as they happen: the
/// last few done ones with a check, and the current one with the
/// breathing ✦ in purple and its text sweeping (Motion v2's one loop):
/// “Sending to Claude Code…” before the first step, “Writing the answer…”
/// after the last.
struct AssistantChatStepsList: View {
    let progress: AssistantChatProgress
    let client: String

    /// The most done steps shown; earlier ones are counted.
    static let shownLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            let done = progress.isWriting ? progress.steps[...] : progress.steps.dropLast()
            let hidden = done.count - min(done.count, Self.shownLimit)
            if hidden > 0 {
                Text("\(hidden) earlier steps", comment: "kind:progress-step · steps no longer listed")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(.leading, Metrics.chatLeadSize)
            }
            ForEach(done.suffix(Self.shownLimit)) { step in
                row(step.text, isCurrent: false)
            }
            row(progress.text(client: client), isCurrent: true)
        }
        // One element read by its label alone: combining the rows under a
        // label of its own made SwiftUI's label lookup recurse until it
        // crashed under XCUITest (and so VoiceOver).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(progress.accessibilityLabel(client: client)))
        .accessibilityIdentifier("chat.steps")
    }

    private func row(_ text: String, isCurrent: Bool) -> some View {
        HStack(spacing: Spacing.xSmall) {
            Group {
                if isCurrent {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                        .foregroundStyle(Palette.ai)
                        .aiBreathing(true)
                } else {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(Palette.ok)
                }
            }
            .frame(width: Metrics.chatLeadSize - Spacing.xSmall)
            Text(text)
                .atlasTextStyle(.callout)
                .fontWeight(isCurrent ? .medium : .regular)
                .foregroundStyle(isCurrent ? Palette.label : Palette.label2)
                .lineLimit(1)
                .truncationMode(.middle)
                .aiSweep(isCurrent)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.large) {
        AssistantChatStepsList(progress: AssistantChatProgress(), client: "Claude Code")
        AssistantChatStepsList(
            progress: AssistantChatProgress(steps: [.init(id: 1, text: "Read apps"), .init(id: 2, text: "Read store page")]),
            client: "Claude Code"
        )
        AssistantChatStepsList(
            progress: AssistantChatProgress(steps: [.init(id: 1, text: "Read apps"), .init(id: 2, text: "Read store page")], isWriting: true),
            client: "Claude Code"
        )
    }
    .padding()
}
