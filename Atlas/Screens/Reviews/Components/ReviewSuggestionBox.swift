//
//  ReviewSuggestionBox.swift
//  Atlas
//

import SwiftUI

/// A suggested reply under a review: in the reviewer's language, with what
/// it means, who suggested it, and Dismiss, Edit… and Send Reply. It says
/// the reply is public before it's sent.
struct ReviewSuggestionBox: View {
    let review: AppReview
    let suggestion: ReviewReplySuggestion
    let isSending: Bool
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.machineTranslated)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
            }
            Text(suggestion.text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, ReviewLanguage.isRightToLeft(review.languageCode) ? .rightToLeft : .leftToRight)
                .accessibilityIdentifier("reviews.suggestion.text.\(review.id)")
            if !suggestion.meaning.isEmpty {
                Text("In \(ReviewLanguage.appLanguageName): \(suggestion.meaning)")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: Spacing.small) {
                Text("Public on the App Store. You can edit or delete it later.")
                    .font(.caption)
                    .foregroundStyle(Palette.label3)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss", action: onDismiss)
                    .accessibilityIdentifier("reviews.suggestion.dismiss.\(review.id)")
                Button("Edit…", action: onEdit)
                    .accessibilityIdentifier("reviews.suggestion.edit.\(review.id)")
                Button("Send Reply", action: onSend)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending)
                    .accessibilityIdentifier("reviews.suggestion.send.\(review.id)")
            }
            .controlSize(.small)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.machineTranslatedTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.machineTranslatedMark.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.suggestion.\(review.id)")
    }

    /// "Suggested reply, in German", or "A reply is optional" for 5 stars.
    private var label: String {
        if review.replyIsOptional { return String(localized: "A reply is optional") }
        let language = review.languageCode.isEmpty ? ReviewLanguage.appLanguageName : ReviewLanguage.name(of: review.languageCode)
        return String(localized: "Suggested reply, in \(language)")
    }
}
