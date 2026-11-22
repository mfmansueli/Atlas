//
//  ReviewThemeCard.swift
//  Atlas
//

import SwiftUI

/// One group of reviews: its subject, how many and where from, what the
/// assistant noticed, and the one thing to do about it.
struct ReviewThemeCard: View {
    let summary: ReviewThemeSummary
    let action: () -> Void

    var body: some View {
        Card(padding: Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(summary.theme.title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary.countText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .fixedSize()
            }
            if !whereText.isEmpty {
                Text(whereText)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !summary.theme.note.isEmpty {
                Text(summary.theme.note)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(summary.buttonTitle, action: action)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .disabled(!summary.isButtonEnabled)
                .accessibilityIdentifier("reviews.theme.action.\(summary.id)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.theme.\(summary.id)")
    }

    /// "Germany 14 · Japan 11 · U.S. 6 · 4 more · mostly 1–2 ★".
    private var whereText: String {
        [summary.whereText, summary.isMostlyLow ? String(localized: "mostly 1–2 ★") : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
