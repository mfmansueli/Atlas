//
//  AnalyticsColumns.swift
//  Atlas
//

import SwiftUI

/// A table row (or its header) inside an `AnalyticsBox`: the first cell
/// takes what's left, the others the given widths.
struct AnalyticsColumns: View {
    let cells: [AnyView]
    let widths: [CGFloat]
    var isHeader = false

    init(_ cells: [AnyView], widths: [CGFloat], isHeader: Bool = false) {
        self.cells = cells
        self.widths = widths
        self.isHeader = isHeader
    }

    /// A header of plain titles.
    init(titles: [String], widths: [CGFloat]) {
        self.init(titles.map { AnyView(Text($0)) }, widths: widths, isHeader: true)
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                if index == 0 {
                    cell.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    cell.frame(width: widths.indices.contains(index - 1) ? widths[index - 1] : 90, alignment: .trailing)
                }
            }
        }
        .font(isHeader ? .caption.weight(.semibold) : .callout)
        .foregroundStyle(isHeader ? Palette.label2 : Palette.label)
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, isHeader ? Spacing.small : Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}
