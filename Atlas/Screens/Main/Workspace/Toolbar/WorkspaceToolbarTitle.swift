//
//  WorkspaceToolbarTitle.swift
//  Atlas
//

import SwiftUI

/// The section's title in the toolbar, over its state: “32 suggestions in
/// 6 languages · 3 not pushed”. The not-pushed count is a link that opens
/// Review & Push showing only this section. It replaces the title row the
/// pages had under the toolbar. The ? beside the title opens the section's
/// Help article.
struct WorkspaceToolbarTitle: View {
    let title: String
    let status: WorkspaceSectionStatus
    /// The most it may take, so the toolbar's actions keep their place at
    /// the trailing edge (`WorkspaceToolbarLayout.titleRoom`); nil, as
    /// wide as it wants up to its cap.
    var maxWidth: CGFloat?
    /// “3 not pushed”: Review & Push for this section.
    let onNotPushed: () -> Void

    var body: some View {
        texts
            .frame(maxWidth: maxWidth, alignment: .leading)
            // Its whole width, up to the room it has: a status that grows
            // after the toolbar sized the item (“Nothing waiting” once
            // Pricing has read its products, the version once read) widens
            // the item. Squeezed, it truncates in its place rather than
            // spilling under the sidebar button.
            .toolbarItemFit([title, status.text, maxWidth.map { "\(Int($0))" } ?? ""])
            // As wide as it wants, measured out of sight, so the toolbar
            // knows how much it would truncate.
            .background {
                texts
                    .fixedSize()
                    .hidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .reportsToolbarRoom(.title)
            }
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xxSmall) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("workspace.title")
                SectionHelpButton(section: status.section)
                    // A 24 pt hit area in a two-line title: it overhangs
                    // the line rather than heightening it.
                    .frame(height: 0)
            }
            .frame(maxWidth: WorkspaceToolbarLayout.maxTitleWidth, alignment: .leading)
            HStack(spacing: 0) {
                if let leading = status.leadingText {
                    Text(leading)
                        .foregroundStyle(Palette.label2)
                }
                if let notPushed = status.notPushedText {
                    if status.leadingText != nil {
                        Text(verbatim: " · ")
                            .foregroundStyle(Palette.label2)
                            .accessibilityHidden(true)
                    }
                    Button(notPushed, action: onNotPushed)
                        .buttonStyle(.link)
                        .underline()
                        .help("Review & Push, only \(title)")
                        .accessibilityIdentifier("workspace.notPushed")
                }
                if status.leadingText == nil, status.notPushedText == nil {
                    Text(status.text)
                        .foregroundStyle(Palette.label2)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: WorkspaceToolbarLayout.maxTitleWidth, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("workspace.status")
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }
}

#Preview {
    WorkspaceToolbarTitle(
        title: "Store Page", status: WorkspaceSectionStatus(section: .storePage, waiting: 32, notPushed: 3)
    ) {}
        .padding()
}
