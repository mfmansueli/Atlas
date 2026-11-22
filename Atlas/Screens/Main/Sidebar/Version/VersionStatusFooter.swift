//
//  VersionStatusFooter.swift
//  Atlas
//

import SwiftUI

/// The sidebar's footer: the version's status, in view from every
/// section, with the one thing to do when there is one. A click opens the
/// Submit sheet before submitting, the Overview's version card after.
struct VersionStatusFooter: View {
    let summary: VersionStatusSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Self.color(summary.tone))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if !summary.text.isEmpty {
                        Text(summary.text)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let title = summary.actionTitle {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background(Palette.accent, in: Capsule())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, Spacing.small)
            .padding(.vertical, Spacing.small)
            .background(Palette.fill1, in: shape)
            .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary.accessibilityText))
        .accessibilityHint(Text(summary.actionTitle ?? String(localized: "Opens Overview")))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sidebar.version")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
    }

    static func color(_ tone: VersionStatusSummary.Tone) -> Color {
        switch tone {
        case .neutral: Palette.label3
        case .active: Palette.accent
        case .good: Palette.positive
        case .warning: Palette.warningMark
        case .bad: Palette.dangerMark
        }
    }
}

#Preview {
    VStack {
        VersionStatusFooter(summary: VersionStatusSummary(versionString: "1.4", phase: .prepare)) {}
        VersionStatusFooter(summary: VersionStatusSummary(versionString: "1.4", phase: .phased(day: 3, isPaused: false))) {}
        VersionStatusFooter(summary: VersionStatusSummary(versionString: "1.4", phase: .rejected)) {}
    }
    .frame(width: 240)
    .padding()
}
