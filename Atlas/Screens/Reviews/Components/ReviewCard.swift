//
//  ReviewCard.swift
//  Atlas
//

import SwiftUI

/// One review: stars, where and when, its title and text (translated, with
/// Show Original), and what stands under it: a suggested reply, the reply
/// being written, the reply sent, or the way to write one.
struct ReviewCard: View {
    let review: AppReview
    @Bindable var viewModel: ReviewsViewModel

    var body: some View {
        let text = viewModel.displayText(for: review)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            header
            if !text.title.isEmpty {
                Text(text.title)
                    .font(.headline)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, text.isRightToLeft ? .rightToLeft : .leftToRight)
                    .accessibilityIdentifier("reviews.card.title.\(review.id)")
            }
            Text(text.body)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, text.isRightToLeft ? .rightToLeft : .leftToRight)
            if let note = text.note {
                translationLine(note, toggle: text.toggleTitle)
            }
            below
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityText(title: text.title)))
        .accessibilityIdentifier("reviews.card.\(review.id)")
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            ReviewStars(rating: review.rating)
            if !review.territory.isEmpty {
                FlagTile(regionCode: review.territory)
            }
            Text(metaText)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
            Spacer(minLength: Spacing.small)
            if ReviewCrashMentions.mentionsCrash(review) {
                Pill(text: String(localized: "Mentions a crash"), style: .warning)
                    .fixedSize()
                    .accessibilityIdentifier("reviews.mentionsCrash.\(review.id)")
            }
            if let theme = viewModel.theme(of: review), viewModel.isPro {
                Pill(text: theme.title, style: .outline)
                    .fixedSize()
            }
        }
    }

    /// "Germany · Version 1.3 · Nov 15".
    private var metaText: String {
        var parts: [String] = []
        if !review.territory.isEmpty { parts.append(review.territoryName) }
        if let version = review.version { parts.append(String(localized: "Version \(version)")) }
        parts.append(ReviewText.day(review.date))
        return parts.joined(separator: " · ")
    }

    private func translationLine(_ note: String, toggle: String?) -> some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "globe")
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text(note)
                .font(.caption)
                .foregroundStyle(Palette.label3)
            if let toggle {
                Button(toggle) { viewModel.toggleTranslation(review) }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .accessibilityIdentifier("reviews.card.translation.\(review.id)")
            }
        }
    }

    // MARK: - Under the review

    @ViewBuilder
    private var below: some View {
        if viewModel.editingID == review.id {
            ReviewReplyEditor(
                review: review,
                text: Binding { viewModel.draft(for: review) } set: { viewModel.drafts[review.id] = $0 },
                meaning: viewModel.draftMeaning(for: review),
                error: viewModel.replyErrors[review.id],
                isSending: viewModel.sending.contains(review.id),
                canSend: viewModel.canSend(viewModel.draft(for: review)),
                onCancel: { viewModel.cancelEditing() },
                onSend: { Task { await viewModel.sendDraft(for: review) } }
            )
        } else if let reply = review.reply {
            let justSent = viewModel.sentNow.contains(review.id)
            ReviewReplyBox(
                review: review, reply: reply, wasJustSent: justSent,
                statusText: justSent ? viewModel.sentText(for: reply) : viewModel.repliedText(for: reply)
            ) {
                viewModel.startEditing(review)
            }
            failure
        } else if let suggestion = viewModel.suggestion(for: review) {
            ReviewSuggestionBox(
                review: review, suggestion: suggestion, isSending: viewModel.sending.contains(review.id),
                autoReply: viewModel.autoReplyDraft(for: review),
                onDismiss: { viewModel.dismissSuggestion(for: review) },
                onEdit: { viewModel.startEditing(review) },
                onSend: { Task { await viewModel.sendSuggestion(for: review) } },
                onDontSend: { viewModel.dontSend(review) }
            )
            failure
        } else {
            writeRow
            failure
        }
    }

    @ViewBuilder
    private var failure: some View {
        if let error = viewModel.replyErrors[review.id] {
            InlineMessage.error(error)
                .font(.caption)
                .accessibilityIdentifier("reviews.card.error.\(review.id)")
        }
    }

    /// No suggestion showing: why, and the way to write a reply by hand.
    private var writeRow: some View {
        HStack(spacing: Spacing.small) {
            Text(writeText)
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.isDismissed(review) {
                Button("Restore") { viewModel.restoreSuggestion(for: review) }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("reviews.card.restore.\(review.id)")
            }
            Button("Write a Reply…") { viewModel.startEditing(review) }
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("reviews.card.write.\(review.id)")
        }
        .controlSize(.small)
    }

    private var writeText: String {
        if !viewModel.isPro { return String(localized: "Pro suggests a reply in the reviewer’s language.") }
        if viewModel.isDismissed(review) { return String(localized: "Suggested reply dismissed. The review still has no reply.") }
        return review.replyIsOptional ? String(localized: "A reply is optional.") : String(localized: "No reply suggested yet.")
    }

    /// "1 star review from Germany: Sync broken since 1.3".
    private func accessibilityText(title: String) -> String {
        let stars = ReviewText.starsSpoken(review.rating)
        return review.territory.isEmpty
            ? String(localized: "\(stars) review: \(title)")
            : String(localized: "\(stars) review from \(review.territoryName): \(title)")
    }
}
