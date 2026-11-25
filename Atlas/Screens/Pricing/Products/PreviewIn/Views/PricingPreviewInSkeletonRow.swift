//
//  PricingPreviewInSkeletonRow.swift
//  Atlas
//

import SwiftUI

/// A product in "Preview in" whose prices are still loading: its name,
/// price and US dollars in grey.
struct PricingPreviewInSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                SkeletonBlock(width: 112)
                Spacer(minLength: Spacing.small)
                SkeletonBlock(width: 56)
            }
            HStack {
                Spacer(minLength: Spacing.small)
                SkeletonBlock(width: 72, height: 8)
            }
        }
        .padding(.vertical, Spacing.xxSmall)
        .accessibilityHidden(true)
    }
}
