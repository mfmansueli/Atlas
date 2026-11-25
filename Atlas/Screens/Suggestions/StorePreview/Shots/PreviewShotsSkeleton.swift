//
//  PreviewShotsSkeleton.swift
//  Atlas
//

import SwiftUI

/// The App Store preview's row while the live sets are read: grey tiles
/// shaped like iPhone screenshots and the line under them, still.
struct PreviewShotsSkeleton: View {
    /// A tile's width, as the screenshots will have it.
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                ForEach(0..<PreviewShotsStrip.placeholderCount, id: \.self) { _ in
                    SkeletonBlock(width: width, height: (width * PreviewShotsStrip.placeholderAspect).rounded(), cornerRadius: Radius.field)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            SkeletonBlock(width: width * 2, height: Spacing.small)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading screenshots"))
        .accessibilityIdentifier("storePreview.shots")
    }
}
