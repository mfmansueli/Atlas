//
//  AnalyticsSetupSteps.swift
//  Atlas
//

import SwiftUI

/// A short numbered list on a setup state: what happened, what's
/// happening, what comes next.
struct AnalyticsSetupSteps: View {
    let steps: [AnalyticsSetupStep]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
                    Group {
                        switch step.state {
                        case .done: Image(systemName: "checkmark")
                        case .current, .upcoming: Text("\(index + 1)")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(step.state == .current ? Color.white : Palette.label2)
                    .frame(width: 20, height: 20)
                    .background(step.state == .current ? Palette.accent : Palette.fill2, in: Circle())
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.callout.weight(.semibold))
                        Text(step.detail).font(.callout).foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }
}
