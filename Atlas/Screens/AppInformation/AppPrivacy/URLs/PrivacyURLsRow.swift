//
//  PrivacyURLsRow.swift
//  Atlas
//

import SwiftUI

/// One locale: its name (with the unpushed dot), and its two URLs as
/// fields that queue a change as they're typed, with what's wrong below.
struct PrivacyURLsRow: View {
    /// The locale column's width; the header lines up with it.
    static let localeWidth: CGFloat = 176

    let table: PrivacyURLsTable
    let locale: StoreLocale
    let viewModel: AppPrivacyViewModel
    /// The suggestion bar's arrows went here: an edge in the AI colour.
    var isFocused = false

    var body: some View {
        let isPending = table.isPolicyPending(locale) || table.isChoicesPending(locale)
        HStack(alignment: .top, spacing: Spacing.small) {
            HStack(spacing: Spacing.xSmall) {
                LocaleLabel(locale: locale, showsTags: false)
                if isPending {
                    UnsavedDot()
                        .accessibilityLabel(Text("Not pushed"))
                }
            }
            .frame(width: Self.localeWidth, alignment: .leading)
            .padding(.top, 4)
            field(
                String(localized: "Privacy Policy URL, \(locale.name)"),
                value: table.policyURL(locale),
                prompt: String(localized: "Required"),
                problem: table.policyProblem(locale),
                id: "policy"
            ) { viewModel.setPolicyURL(locale, to: $0) }
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                field(
                    String(localized: "User Privacy Choices URL, \(locale.name)"),
                    value: table.choicesURL(locale),
                    prompt: String(localized: "Optional"),
                    problem: table.choicesProblem(locale),
                    id: "choices"
                ) { viewModel.setChoicesURL(locale, to: $0) }
                // An assistant's suggested URL, under the field.
                if let owner = viewModel.owner {
                    AppInformationFieldSuggestions(viewModel: owner, slot: .privacyChoicesURL(locale))
                        .padding(.horizontal, -(Spacing.medium + 2))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.xSmall)
        .overlay(alignment: .leading) {
            if isFocused {
                Rectangle()
                    .fill(Palette.aiEdge)
                    .frame(width: 3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.urls.\(locale.code)")
    }

    private func field(
        _ label: String,
        value: String,
        prompt: String,
        problem: String?,
        id: String,
        onChange: @escaping @MainActor (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(label, text: Binding(get: { value }, set: onChange), prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("appInformation.appPrivacy.urls.\(locale.code).\(id)")
            if let problem {
                Text(problem)
                    .font(.subheadline)
                    .foregroundStyle(Palette.err)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
