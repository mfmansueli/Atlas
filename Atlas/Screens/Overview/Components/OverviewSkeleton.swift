//
//  OverviewSkeleton.swift
//  Atlas
//

import SwiftUI

/// Placeholder header and cards while the first summaries load: the
/// cards' shape, static and grey (README §17 · overview cards).
struct OverviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            SkeletonLine(fraction: SkeletonPattern.primary[0], height: Metrics.skeletonOverviewTitle)
                .frame(maxWidth: Metrics.skeletonOverviewTitleWidth, alignment: .leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.overviewCardMinimumWidth), spacing: Spacing.medium)], spacing: Spacing.medium) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonCard(height: Metrics.skeletonOverviewCardHeight, lines: 2)
                }
            }
        }
        .loadingSkeleton(LoadingCopy.overview, identifier: "overview.skeleton")
    }
}

#Preview {
    OverviewSkeleton()
        .padding()
        .frame(width: 800)
}
