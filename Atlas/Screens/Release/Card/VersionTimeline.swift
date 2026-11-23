//
//  VersionTimeline.swift
//  Atlas
//

import SwiftUI

/// The version's way to the App Store as five steps on a line: Submitted,
/// Waiting for Review, In Review, Approved, On the App Store.
struct VersionTimeline: View {
    let steps: [ReleaseStep]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(steps) { step in
                VStack(alignment: .leading, spacing: 2) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(step.state == .done ? Palette.accent : Palette.fill3)
                            .frame(height: 2)
                            .opacity(step.id == steps.count - 1 ? 0 : 1)
                        Circle()
                            .fill(color(step.state))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(ring(step.state), lineWidth: 3).padding(-4))
                    }
                    .frame(height: 20)
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(step.detail.isEmpty ? " " : step.detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
                .padding(.trailing, Spacing.xSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilityText(step)))
                .accessibilityIdentifier("overview.version.step.\(step.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.version.steps")
    }

    private func color(_ state: ReleaseStep.State) -> Color {
        switch state {
        case .done, .current: Palette.accent
        case .upcoming: Palette.fill3
        case .rejected: Palette.errMark
        }
    }

    private func ring(_ state: ReleaseStep.State) -> Color {
        switch state {
        case .current: Palette.accentTint
        case .rejected: Palette.errTint
        case .done, .upcoming: .clear
        }
    }

    /// "Waiting for Review, now, Usually about a day".
    private func accessibilityText(_ step: ReleaseStep) -> String {
        let state = switch step.state {
        case .done: String(localized: "done")
        case .current: String(localized: "now")
        case .upcoming: String(localized: "not yet")
        case .rejected: String(localized: "sent back")
        }
        return [step.title, state, step.detail].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
