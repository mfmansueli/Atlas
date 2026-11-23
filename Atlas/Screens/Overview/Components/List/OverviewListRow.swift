//
//  OverviewListRow.swift
//  Atlas
//

import SwiftUI

/// A row of an Overview list: the section's tile, its name over one line
/// of detail, then what's at the end (a count, Review or Open).
struct OverviewListRow<Trailing: View>: View {
    let section: AppWorkspaceSection
    let title: String
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Spacing.medium) {
                SectionIconTile(section: section, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(detail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
    }
}
