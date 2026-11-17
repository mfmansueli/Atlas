//
//  ReviewReplyBox.swift
//  Atlas
//

import SwiftUI

/// The reply under a review: one just sent ("You replied Nov 16…") or one
/// already on the App Store, each with Edit.
struct ReviewReplyBox: View {
    let review: AppReview
    let reply: ReviewReply
    /// Sent since the section opened.
    let wasJustSent: Bool
    /// "You replied Nov 16. Apple shows it…" or "Your reply · Nov 10 · On
    /// the App Store".
    let statusText: String
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            if wasJustSent {
                Text("Your reply")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.label2)
            } else {
                header
            }
            Text(reply.text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, ReviewLanguage.isRightToLeft(review.languageCode) ? .rightToLeft : .leftToRight)
            if wasJustSent {
                HStack(spacing: Spacing.xSmall) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Palette.label2)
                        .accessibilityHidden(true)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    editButton
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.reply.\(review.id)")
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
            editButton
        }
    }

    private var editButton: some View {
        Button("Edit", action: onEdit)
            .buttonStyle(.link)
            .controlSize(.small)
            .accessibilityIdentifier("reviews.reply.edit.\(review.id)")
    }
}
