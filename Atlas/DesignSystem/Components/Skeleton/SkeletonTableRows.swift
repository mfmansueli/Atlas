//
//  SkeletonTableRows.swift
//  Atlas
//

import SwiftUI

/// Table rows while a table's data loads or refreshes (pricing-skeleton,
/// Store Page's coverage, In-App Purchase texts, privacy URLs): a flag,
/// a name and the columns' cells, under whatever header stays on screen.
///
/// The rows fill the height offered and cut off what doesn't fit, so they
/// never raise the window's minimum height: rigid rows under a bar whose
/// wrapping changes its height once made that minimum never settle. Nor
/// its minimum width: names and cells shrink before the window would grow.
struct SkeletonTableRows: View {
    var count = 12
    var rowHeight: CGFloat = Metrics.tableRowHeight
    /// The leading flag; false starts with the name.
    var showsFlag = true
    var cells = 4
    var cellWidth: CGFloat = Metrics.skeletonCellWidth
    var showsDividers = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<max(count, 0), id: \.self) { index in
                HStack(spacing: Spacing.large) {
                    if showsFlag {
                        SkeletonBlock(width: Metrics.skeletonFlagWidth, height: Metrics.skeletonFlagHeight, cornerRadius: Radius.flag)
                    }
                    // Names and cells give way in a narrow window rather than
                    // widen it: each takes up to its width, never needs it.
                    SkeletonBlock(height: Metrics.skeletonLine)
                        .frame(minWidth: 0, maxWidth: Metrics.skeletonNameWidth * nameScale(index))
                    Spacer(minLength: Spacing.large)
                    ForEach(0..<max(cells, 0), id: \.self) { _ in
                        SkeletonBlock(height: Metrics.skeletonLine)
                            .frame(minWidth: 0, maxWidth: cellWidth)
                    }
                }
                .padding(.horizontal, Spacing.small)
                .frame(height: rowHeight)
                if showsDividers {
                    Divider()
                }
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityHidden(true)
    }

    /// Names a little longer or shorter, row after row.
    private func nameScale(_ index: Int) -> CGFloat {
        SkeletonPattern.fraction(row: index, line: 0) / SkeletonPattern.primary[0]
    }
}

#Preview {
    SkeletonTableRows(showsDividers: true)
        .frame(width: 700, height: 300)
}
