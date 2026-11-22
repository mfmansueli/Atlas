//
//  ConnectHowItWorks.swift
//  Atlas
//

import SwiftUI

/// Nothing connected yet (`set-assistants-new`): the three steps, in
/// pills above the assistants.
struct ConnectHowItWorks: View {
    private let steps = [
        String(localized: "Choose the assistant you use"),
        String(localized: "Click Connect"),
        String(localized: "Atlas checks that it works"),
    ]

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: Spacing.small) {
                    ConnectStepMark(number: index + 1, state: .now, size: 20)
                    Text(step)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, Spacing.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("How it works"))
        .accessibilityIdentifier("settings.ai.howItWorks")
    }
}
