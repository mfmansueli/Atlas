//
//  AppSaleQueuedBox.swift
//  Atlas
//

import SwiftUI

/// What an App Price or Availability change waiting in Review & Push
/// sets, with Change…, Discard and Review & Push.
struct AppSaleQueuedBox: View {
    let text: String
    var problem: String?
    let identifier: String
    let onChange: (() -> Void)?
    let onDiscard: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Label {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(Palette.accentText)
            }
            .font(.callout)
            .accessibilityIdentifier("\(identifier).text")
            if let problem {
                InlineMessage.error(problem)
                    .font(.subheadline)
            }
            HStack(spacing: Spacing.small) {
                Button("Review & Push…", action: onReview)
                    .accessibilityIdentifier("\(identifier).review")
                Spacer(minLength: Spacing.small)
                Button("Discard", action: onDiscard)
                    .accessibilityIdentifier("\(identifier).discard")
                if let onChange {
                    Button("Change…", action: onChange)
                        .accessibilityIdentifier("\(identifier).change")
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
