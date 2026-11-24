//
//  WorkspaceToolbarTitle.swift
//  Atlas
//

import SwiftUI

/// The section's title in the toolbar, over its state: “32 suggestions in
/// 6 languages · 3 not pushed”. The not-pushed count is a link that opens
/// Review & Push showing only this section. It replaces the title row the
/// pages had under the toolbar.
struct WorkspaceToolbarTitle: View {
    let title: String
    let status: WorkspaceSectionStatus
    /// “3 not pushed”: Review & Push for this section.
    let onNotPushed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: WorkspaceToolbarLayout.maxTitleWidth, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workspace.title")
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
        // Its whole width, up to the cap: a status that grows after the
        // toolbar sized the item (“Nothing waiting” once Pricing has read
        // its products, the version once read) widens the item. Squeezed,
        // it truncates in its place rather than spilling under the
        // sidebar button.
        .toolbarItemFit([title, status.text])
    }
}

#Preview {
    WorkspaceToolbarTitle(
        title: "Store Page", status: WorkspaceSectionStatus(section: .storePage, waiting: 32, notPushed: 3)
    ) {}
        .padding()
}
