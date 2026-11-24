//
//  AssistantChatStepsList.swift
//  Atlas
//

import SwiftUI

/// The steps of the answer being worked on, counted as they happen: the
/// last few done ones with a check, and the current one.
struct AssistantChatStepsList: View {
    let steps: [AssistantChatStep]
    let client: String

    /// The most done steps shown; earlier ones are counted.
    static let shownLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            if steps.isEmpty {
                row(String(localized: "Starting \(client)…", comment: "kind:progress-step"), isCurrent: true)
            } else {
                let done = steps.dropLast()
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
                if let current = steps.last {
                    row(String(localized: "\(current.text)…", comment: "kind:progress-step · the step being worked on"), isCurrent: true)
                }
            }
        }
        // One element read by its label alone: combining the rows under a
        // label of its own made SwiftUI's label lookup recurse until it
        // crashed under XCUITest (and so VoiceOver).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(client) is working, step \(max(steps.count, 1))", comment: "kind:accessibility"))
        .accessibilityIdentifier("chat.steps")
    }

    private func row(_ text: String, isCurrent: Bool) -> some View {
        HStack(spacing: Spacing.xSmall) {
            Group {
                if isCurrent {
                    AssistantWorkingDot()
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
        }
    }
}

#Preview {
    AssistantChatStepsList(
        steps: [.init(id: 1, text: "Read apps"), .init(id: 2, text: "Read store page"), .init(id: 3, text: "Read CHANGELOG.md")],
        client: "Claude Code"
    )
    .padding()
}
