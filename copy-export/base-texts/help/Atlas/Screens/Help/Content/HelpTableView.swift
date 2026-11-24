//
//  HelpTableView.swift
//  Atlas
//

import SwiftUI

/// A Help article's table: the header in bold, a line between rows.
struct HelpTableView: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.large, verticalSpacing: Spacing.small) {
            GridRow {
                ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                    Text(cell)
                        .font(.callout.weight(.semibold))
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider()
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("help.table")
    }
}
