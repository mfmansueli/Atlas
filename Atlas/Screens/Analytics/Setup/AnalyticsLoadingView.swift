//
//  AnalyticsLoadingView.swift
//  Atlas
//

import SwiftUI

/// The first download (an-loading): a static grey skeleton of the
/// Overview's number cards and funnel over what's being read, each of
/// Apple's reports ticked as it arrives. No spinner: the steps are the
/// progress, counted.
struct AnalyticsLoadingView: View {
    let appName: String
    /// Steps already finished.
    let finished: Int

    var body: some View {
        let message = LoadingCopy.analytics(appName: appName)
        VStack(spacing: Spacing.large) {
            HStack(spacing: Spacing.small) {
                ForEach(AnalyticsKPI.Kind.allCases, id: \.self) { _ in
                    SkeletonCard(height: Metrics.skeletonFunnelStageHeight, lines: 1)
                }
            }
            .frame(minWidth: 0)
            .accessibilityHidden(true)
            HStack(spacing: Spacing.small) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBlock(height: Metrics.skeletonFunnelStageHeight, cornerRadius: Radius.card)
                }
            }
            .frame(minWidth: 0)
            .accessibilityHidden(true)
            Card {
                Text(message.line ?? message.spoken)
                    .atlasTextStyle(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(AnalyticsActivity.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: Spacing.small) {
                        Image(systemName: index < finished ? "checkmark" : "circle")
                            .foregroundStyle(index < finished ? Palette.label2 : Palette.label3)
                            .frame(width: Metrics.symbolColumn)
                            .accessibilityHidden(true)
                        Text(step).foregroundStyle(index <= finished ? Palette.label : Palette.label3)
                    }
                    .atlasTextStyle(.callout)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(index < finished ? String(localized: "\(step), done", comment: "kind:label") : step))
                }
                Text("The first download includes earlier data, so it takes a minute.")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: Metrics.skeletonAnalyticsCardWidth)
            Spacer(minLength: 0)
        }
        .padding(.top, Spacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(message.spoken))
        .accessibilityIdentifier("analytics.loading")
    }
}
