//
//  FromAnalyticsBar.swift
//  Atlas
//

import SwiftUI

/// At the top of the section a finding led to (board 92: Store Page in
/// German, Pricing for Brazil): "From Analytics:" and the finding in a
/// sentence, Back to Analytics, which returns to the view it came from,
/// and ✕.
struct FromAnalyticsBar: View {
    let origin: AnalyticsOrigin
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: AppWorkspaceSection.analytics.systemImage)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(.white)
                .frame(width: Metrics.analyticsOriginTile, height: Metrics.analyticsOriginTile)
                .background(Palette.sectionAnalytics, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .accessibilityHidden(true)
            Text("\(Text("From Analytics:", comment: "kind:banner · From Analytics bar").fontWeight(.semibold)) \(Text(origin.text).foregroundStyle(Palette.label2))")
                .atlasTextStyle(.callout)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("analytics.origin.text")
            Button(action: onBack) {
                Label(String(localized: "Back to Analytics", comment: "kind:button · From Analytics bar"), systemImage: "chevron.left")
            }
            .controlSize(.regular)
            .fixedSize()
            .help(Text("Back to \(origin.tab.title) in Analytics", comment: "kind:tooltip · From Analytics bar"))
            .accessibilityIdentifier("analytics.origin.back")
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(Palette.label2)
                .help(Text("Hide", comment: "kind:tooltip · From Analytics bar"))
                .accessibilityLabel(Text("Hide", comment: "kind:accessibility-label · From Analytics bar"))
                .accessibilityIdentifier("analytics.origin.close")
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
