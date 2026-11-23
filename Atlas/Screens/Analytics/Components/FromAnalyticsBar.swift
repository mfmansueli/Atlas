//
//  FromAnalyticsBar.swift
//  Atlas
//

import SwiftUI

/// At the top of the section a finding led to: the finding in a sentence,
/// and the way back.
struct FromAnalyticsBar: View {
    let origin: AnalyticsOrigin
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: AppWorkspaceSection.analytics.systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Palette.sectionAnalytics, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .accessibilityHidden(true)
            Text("\(Text("From Analytics").fontWeight(.semibold)) \(Text(origin.text).foregroundStyle(Palette.label2))")
                .font(.callout)
                .lineLimit(2)
            Spacer(minLength: Spacing.small)
            Button("Back to Analytics", action: onBack)
                .controlSize(.regular)
                .accessibilityIdentifier("analytics.origin.back")
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.label2)
                .accessibilityLabel(Text("Hide"))
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.origin")
    }
}
