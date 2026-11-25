//
//  StorePageTableSkeleton.swift
//  Atlas
//

import SwiftUI

/// Placeholder rows while a table's data loads: a flag, a language and
/// its fields' cells. They fill the height offered and cut off the rest,
/// so the page's minimum height stays the window's.
struct StorePageTableSkeleton: View {
    var rows = 10

    var body: some View {
        SkeletonTableRows(
            count: rows, rowHeight: Metrics.skeletonStorePageRowHeight, cells: 6, cellWidth: Metrics.skeletonStorePageCellWidth,
            showsDividers: true
        )
        .padding(.horizontal, Spacing.small)
    }
}

#Preview {
    StorePageTableSkeleton()
        .frame(width: 800, height: 400)
}
