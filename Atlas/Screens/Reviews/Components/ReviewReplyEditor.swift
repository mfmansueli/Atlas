//
//  ReviewReplyEditor.swift
//  Atlas
//

import SwiftUI

/// The reply being written under a review: the text, what the suggestion
/// it started from means, what Guideline 5.6.1 asks to leave out (a
/// warning: the person may know better), Apple's limit, and Cancel and
/// Send Reply.
struct ReviewReplyEditor: View {
    let review: AppReview
    @Binding var text: String
    /// "Thank you for the kind review…": the suggestion's meaning.
    let meaning: String?
    let error: String?
    let isSending: Bool
    let canSend: Bool
    let onCancel: () -> Void
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            TextEditor(text: $text)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(minHeight: 66, maxHeight: 150)
                .background(Palette.content, in: shape)
                .overlay(shape.strokeBorder(isOverLimit ? Palette.danger : Palette.separator2, lineWidth: isOverLimit ? 1.5 : 1))
                .environment(\.layoutDirection, ReviewLanguage.isRightToLeft(review.languageCode) ? .rightToLeft : .leftToRight)
                .focused($isFocused)
                .accessibilityLabel(Text("Your reply"))
                .accessibilityIdentifier("reviews.editor.text.\(review.id)")
            if let meaning {
                Text("In \(ReviewLanguage.appLanguageName): \(meaning)")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            let issues = StoreTextGuidelineCheck.issues(in: text, for: .reviewReply)
            if !issues.isEmpty {
                InlineMessage.warning(issues.map(\.message).joined(separator: "\n"))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reviews.editor.guideline.\(review.id)")
            }
            if let error {
                InlineMessage.error(error)
                    .font(.caption)
            }
            HStack(spacing: Spacing.small) {
                Text(ReviewText.replyCounter(text))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isOverLimit ? Palette.danger : Palette.label3)
                Text("Public on the App Store.")
                    .font(.caption)
                    .foregroundStyle(Palette.label3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("reviews.editor.cancel.\(review.id)")
                Button("Send Reply", action: onSend)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend || isSending)
                    .accessibilityIdentifier("reviews.editor.send.\(review.id)")
            }
            .controlSize(.small)
            .buttonBorderShape(.capsule)
        }
        .onAppear { isFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.editor.\(review.id)")
    }

    private var isOverLimit: Bool { text.count > ReviewText.replyLimit }
}
