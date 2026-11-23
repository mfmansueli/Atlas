//
//  ScreenshotActivityDetails.swift
//  Atlas
//

import SwiftUI

/// A screenshot push's lines in Activity: the sets it kept on this Mac,
/// and each image that failed with its reason.
struct ScreenshotActivityDetails: View {
    let summary: ScreenshotPushSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(summary.keptTitle)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("activity.kept")
            ForEach(summary.failures, id: \.self) { failure in
                Text(failure)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.err)
                    .textSelection(.enabled)
            }
        }
    }
}
