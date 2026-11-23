//
//  PrivacyOpenQuestionRow.swift
//  Atlas
//

import SwiftUI

/// One of the assistant's questions in its own box. Open: ringed in amber
/// with a Question pill, the types it's about, and Yes and No under it.
/// Answered: a plain box with what the answer did, still changeable.
struct PrivacyOpenQuestionRow: View {
    let question: PrivacyOpenQuestion
    let onAnswer: @MainActor (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                if question.isOpen {
                    Pill(text: String(localized: "Question", comment: "kind:pill"), style: .warning)
                }
                Text(question.question)
                    .font(.callout.weight(question.isOpen ? .semibold : .regular))
                    .foregroundStyle(question.isOpen ? Palette.label : Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AssistantMonogram(letters: ChangeSource.assistant(client: question.client).monogram ?? "AI")
            }
            HStack(alignment: .bottom, spacing: Spacing.small) {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                YesNoPicker(title: question.question, value: question.answer, onSet: onAnswer)
                    .controlSize(.regular)
                    .accessibilityIdentifier("appInformation.appPrivacy.question.\(question.id)")
            }
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(question.isOpen ? Palette.warnMark : Palette.separator, lineWidth: question.isOpen ? 1.5 : 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.questionRow.\(question.id)")
    }

    /// "About: Email Address, Customer Support", or what the answer did.
    private var detail: String {
        if let effect = question.effectSummary {
            let answer = question.answer == true ? String(localized: "Yes") : String(localized: "No")
            return String(localized: "Answered \(answer) · \(effect)")
        }
        return String(localized: "About: \(question.affectedNames)")
    }
}
