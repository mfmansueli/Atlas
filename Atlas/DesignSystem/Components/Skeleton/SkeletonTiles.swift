//
//  SkeletonTiles.swift
//  Atlas
//

import SwiftUI

/// A row of screenshot-shaped tiles while a set's images are read from
/// Apple (Screenshots, Review & Push). The images themselves, once their
/// URLs are known, load through `ImageLoadingTile` / `CachedRemoteImage`.
struct SkeletonTiles: View {
    var count = 5
    var width: CGFloat = Metrics.skeletonTileWidth
    /// Height ÷ width, e.g. an iPhone screenshot's.
    var aspect: CGFloat = Metrics.skeletonTileAspect

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            ForEach(0..<max(count, 0), id: \.self) { _ in
                SkeletonBlock(width: width, height: (width * aspect).rounded(), cornerRadius: Radius.flag)
            }
        }
        .frame(minWidth: 0, alignment: .leading)
        .clipped()
        .accessibilityHidden(true)
    }
}

#Preview {
    SkeletonTiles()
        .padding()
}
