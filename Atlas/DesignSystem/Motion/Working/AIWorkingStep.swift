//
//  AIWorkingStep.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Working with no units to count (README — Design system §7,
/// v2): the assistant reads the project, writes its hello, drafts a reply.
/// Nothing loops: the spark sits still and the step says what happens
/// (“Claude Code is writing…”), in the assistant's message bubble. The same
/// with Reduce Motion. VoiceOver reads the step.
struct AIWorkingStep: View {
    var text: String = .init(localized: "Writing…")

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "sparkle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Palette.aiFill)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundStyle(Palette.label2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Palette.aiSurface, in: Self.bubble)
        .overlay(Self.bubble.strokeBorder(Palette.aiEdge, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityIdentifier("motion.typing")
    }

    /// The design's message bubble: square where it points at the sender.
    static let bubble = UnevenRoundedRectangle(
        topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous
    )
}

#Preview {
    AIWorkingStep(text: "Claude Code is writing…")
        .padding()
}
