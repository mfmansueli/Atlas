//
//  ReviewSuggestionBox.swift
//  Atlas
//

import SwiftUI

/// A suggested reply under a review: in the reviewer's language, with what
/// it means, who suggested it, and Dismiss, Edit… and Send Reply. It says
/// the reply is public before it's sent. Written by Reply Automatically
/// (board 58), it says when it goes out by itself, with Send Now and
/// Don't Send, or why it waits for the person.
struct ReviewSuggestionBox: View {
    let review: AppReview
    let suggestion: ReviewReplySuggestion
    let isSending: Bool
    /// Reply Automatically's record of it, if it wrote it.
    var autoReply: AutoReplyDraft?
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onSend: () -> Void
    /// Don't Send on a reply that goes out by itself.
    var onDontSend: () -> Void = {}

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
            if autoReply != nil {
                // The countdown keeps its word minute by minute.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if let line = autoLine(now: context.date) {
                        Label(line.text, systemImage: line.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(line.isWarning ? Palette.warningMark : Palette.label2)
                            .accessibilityIdentifier("reviews.suggestion.auto.\(review.id)")
                    }
                }
            }
            HStack(spacing: Spacing.small) {
                Text("Public on the App Store. You can edit or delete it later.")
                    .font(.caption)
                    .foregroundStyle(Palette.label3)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isScheduled {
                    Button("Don’t Send", action: onDontSend)
                        .accessibilityIdentifier("reviews.suggestion.dontSend.\(review.id)")
                } else {
                    Button("Dismiss", action: onDismiss)
                        .accessibilityIdentifier("reviews.suggestion.dismiss.\(review.id)")
                }
                Button("Edit…", action: onEdit)
                    .accessibilityIdentifier("reviews.suggestion.edit.\(review.id)")
                Button(isScheduled ? String(localized: "Send Now") : String(localized: "Send Reply"), action: onSend)
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

    private var isScheduled: Bool { autoReply?.state.isScheduled == true }

    /// "Sends by itself in 42 min", "Waits for you: it mentions a crash".
    private func autoLine(now: Date) -> (text: String, icon: String, isWarning: Bool)? {
        guard let autoReply else { return nil }
        switch autoReply.state {
        case let .scheduled(sendAt):
            return (Self.sendsText(sendAt, now: now), "clock", false)
        case let .needsYou(reason):
            return (String(localized: "Waits for you: \(reason)"), "hand.raised", true)
        case .drafted:
            return (String(localized: "Drafted automatically. Nothing goes out until you send it."), "envelope", false)
        case .held:
            return (String(localized: "Won’t go out by itself. Send it when you like."), "pause.circle", false)
        case .sent:
            return nil
        }
    }

    /// "Sends by itself in 42 min", or "Sends by itself at the next tick"
    /// once it's due.
    static func sendsText(_ sendAt: Date, now: Date) -> String {
        let minutes = Int((sendAt.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return String(localized: "Sends by itself in a moment") }
        if minutes < 60 { return String(localized: "Sends by itself in \(minutes) min") }
        return String(localized: "Sends by itself at \(sendAt.formatted(date: .omitted, time: .shortened))")
    }

    /// "Suggested reply, in German", or "A reply is optional" for 5 stars.
    private var label: String {
        if autoReply != nil { return String(localized: "Reply drafted by Claude") }
        if review.replyIsOptional { return String(localized: "A reply is optional") }
        let language = review.languageCode.isEmpty ? ReviewLanguage.appLanguageName : ReviewLanguage.name(of: review.languageCode)
        return String(localized: "Suggested reply, in \(language)")
    }
}
