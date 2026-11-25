//
//  ScreenshotsSkeleton.swift
//  Atlas
//

import SwiftUI

/// The Screenshots section while its sets are read from Apple: what's
/// being read, then the sets' rows (a flag, a language and its
/// screenshots), static and grey. Rows that don't fit are cut off, so the
/// page keeps the window's minimum size.
struct ScreenshotsSkeleton: View {
    var rows = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if let line = LoadingCopy.screenshots.line {
                LoadingLine(text: line)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rows, id: \.self) { index in
                    HStack(spacing: Spacing.medium) {
                        SkeletonBlock(width: Metrics.skeletonFlagWidth, height: Metrics.skeletonFlagHeight, cornerRadius: Radius.flag)
                        SkeletonLine(fraction: SkeletonPattern.fraction(row: index, line: 0))
                            .frame(width: Metrics.skeletonNameWidth)
                        SkeletonTiles(count: 6)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Spacing.xSmall)
                    Divider()
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .padding(EdgeInsets(top: Spacing.medium, leading: Spacing.xLarge, bottom: 0, trailing: Spacing.xLarge))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .loadingSkeleton(LoadingCopy.screenshots, identifier: "screenshots.loading")
    }
}

#Preview {
    ScreenshotsSkeleton()
        .frame(width: 800, height: 500)
}
