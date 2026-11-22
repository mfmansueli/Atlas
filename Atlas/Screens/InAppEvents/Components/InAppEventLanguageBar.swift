//
//  InAppEventLanguageBar.swift
//  Atlas
//

import SwiftUI

/// Above an event's texts: how many languages were suggested, Dismiss All
/// and Accept All Languages, and a chip per language.
struct InAppEventLanguageBar: View {
    @Bindable var viewModel: InAppEventsViewModel
    let languages: [InAppEventLanguage]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text(viewModel.suggestionsTitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("events.languages.title")
                if viewModel.suggestedCount > 0 {
                    Button("Dismiss All") {
                        viewModel.dismissAllLanguages()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .help("Dismiss every suggested language and revision of this event. You can undo it.")
                    .accessibilityLabel(Text("Dismiss All, \(viewModel.suggestedCount) suggested"))
                    .accessibilityIdentifier("events.dismissAll")
                    Button {
                        viewModel.acceptAllLanguages()
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Image(systemName: "sparkles")
                            Text("Accept All Languages")
                            SuggestionBadge(count: viewModel.suggestedCount, isSmall: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityLabel(Text("Accept All Languages, \(viewModel.suggestedCount) suggested"))
                    .accessibilityIdentifier("events.acceptAll")
                }
            }
            FlowLayout(spacing: Spacing.xSmall, lineSpacing: Spacing.xSmall) {
                ForEach(languages) { language in
                    InAppEventLanguageChip(language: language, isSelected: language.code == viewModel.localeCode) {
                        viewModel.localeCode = language.code
                    }
                    .accessibilityIdentifier("events.language.\(language.code)")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.languageBar")
    }
}
