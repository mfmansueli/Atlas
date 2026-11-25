//
//  SkeletonRows.swift
//  Atlas
//

import SwiftUI

/// Grey list rows while a list's data loads: the sidebar's rows (lib-loading),
/// the app menu, a library of files. Each row has an optional leading tile
/// (an app icon, a section symbol, a thumbnail), one or two text lines and
/// optional trailing cells. Static: no shimmer, no pulse.
///
/// Rows that don't fit are cut off rather than raising the page's minimum
/// height (the trap of a fixed-height skeleton under width-adaptive bars).
/// Callers give the whole skeleton one VoiceOver label with
/// `.loadingSkeleton(_:identifier:)`.
struct SkeletonRows: View {
    var count = 6
    /// The leading tile's size; nil draws none.
    var tile: CGSize? = CGSize(width: Metrics.skeletonIcon, height: Metrics.skeletonIcon)
    var tileRadius: CGFloat = Radius.menuRow
    /// One line (a name) or two (a name over a detail).
    var lines = 2
    var rowHeight: CGFloat = Metrics.skeletonListRowHeight
    /// Short blocks at the trailing edge, e.g. a state or a size.
    var trailingCells = 0
    var showsDividers = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<max(count, 0), id: \.self) { index in
                row(index)
                if showsDividers, index < count - 1 {
                    Divider()
                }
            }
        }
        .frame(minHeight: 0, alignment: .top)
        .clipped()
        .accessibilityHidden(true)
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: Spacing.small) {
            if let tile {
                SkeletonBlock(width: tile.width, height: tile.height, cornerRadius: tileRadius)
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                SkeletonLine(fraction: SkeletonPattern.fraction(row: index, line: 0))
                if lines > 1 {
                    SkeletonLine(fraction: SkeletonPattern.fraction(row: index, line: 1), height: Metrics.skeletonCaptionLine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<max(trailingCells, 0), id: \.self) { _ in
                SkeletonBlock(width: Metrics.skeletonCellWidth, height: Metrics.skeletonLine)
            }
        }
        .padding(.horizontal, Spacing.small)
        .frame(height: rowHeight)
    }
}

#Preview {
    VStack(spacing: Spacing.large) {
        SkeletonRows(count: 3)
        SkeletonRows(count: 3, tile: nil, lines: 1, rowHeight: Metrics.tableRowHeight, trailingCells: 2, showsDividers: true)
    }
    .padding()
    .frame(width: 320)
}
