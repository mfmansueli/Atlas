//
//  AnalyticsLoadingView.swift
//  Atlas
//

import SwiftUI

/// The first download: a skeleton of the funnel over what's being read.
struct AnalyticsLoadingView: View {
    let appName: String
    /// Steps already finished.
    let finished: Int

    var body: some View {
        VStack(spacing: Spacing.large) {
            HStack(spacing: Spacing.small) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBlock(height: 74)
                }
            }
            .accessibilityHidden(true)
            Card {
                Text("Downloading Apple’s reports for \(appName)")
                    .font(.headline)
                ForEach(Array(AnalyticsActivity.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: Spacing.small) {
                        if index < finished {
                            Image(systemName: "checkmark").foregroundStyle(Palette.label2)
                        } else if index == finished {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "circle").foregroundStyle(Palette.label3)
                        }
                        Text(step).foregroundStyle(index <= finished ? Palette.label : Palette.label3)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
                }
                Text("The first download includes earlier data, so it takes a minute.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            .frame(width: 420)
            Spacer()
        }
        .padding(.top, Spacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.loading")
    }
}
