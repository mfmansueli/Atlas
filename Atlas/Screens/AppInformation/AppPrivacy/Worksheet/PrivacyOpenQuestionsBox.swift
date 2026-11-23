//
//  PrivacyOpenQuestionsBox.swift
//  Atlas
//

import SwiftUI

/// What the code can't answer: a small heading, then each of the
/// assistant's questions in its own box, open ones first (ringed in amber).
/// The worksheet isn't done while one is open.
struct PrivacyOpenQuestionsBox: View {
    let viewModel: AppPrivacyViewModel

    var body: some View {
        let questions = viewModel.worksheet.questions
        let open = questions.count(where: \.isOpen)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text("Open questions · the code can’t answer these")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                Spacer(minLength: Spacing.small)
                Text(open == 0
                    ? String(localized: "All answered")
                    : String(localized: "\(open) of \(questions.count) open · answer them to finish the worksheet"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, Spacing.xxSmall)
            ForEach(questions.sorted { $0.isOpen && !$1.isOpen }) { question in
                PrivacyOpenQuestionRow(question: question) { answer in
                    viewModel.answerQuestion(question.id, with: answer)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.questions")
    }
}
