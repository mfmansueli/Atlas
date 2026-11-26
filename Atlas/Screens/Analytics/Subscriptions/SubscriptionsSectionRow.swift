//
//  SubscriptionsSectionRow.swift
//  Atlas
//

import SwiftUI

/// A line on Subscriptions' summary that opens one of its views: the
/// view's name, what it holds, and "See Offers" (board 92).
struct SubscriptionsSectionRow: View {
    let title: String
    let detail: String
    let button: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        AnalyticsBox {
            HStack(alignment: .center, spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(title)
                        .atlasTextStyle(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(2)
                }
                Spacer(minLength: Spacing.small)
                Button(button, action: action)
                    .controlSize(.regular)
                    .accessibilityIdentifier(identifier)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.small)
        }
    }
}
