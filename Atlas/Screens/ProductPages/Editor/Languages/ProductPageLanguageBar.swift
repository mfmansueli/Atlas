//
//  ProductPageLanguageBar.swift
//  Atlas
//

import SwiftUI

/// The page's languages: which have a suggestion (a purple dot), which
/// have content of their own, and Accept All Languages for the
/// suggested texts (Pro).
struct ProductPageLanguageBar: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        let languages = viewModel.languages(of: page)
        let suggested = viewModel.acceptableTextSuggestions(of: page)
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text(viewModel.languageHeadline(of: page))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pages.languages.title")
                if !suggested.isEmpty {
                    Button {
                        pro.require(.acceptAllLanguages(suggestions: suggested.count, languages: suggested.count)) {
                            viewModel.acceptAllLanguages()
                        }
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Image(systemName: "sparkles")
                            Text("Accept All Languages")
                            SuggestionBadge(count: suggested.count, isSmall: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel(Text("Accept All Languages, \(suggested.count) suggested"))
                    .accessibilityIdentifier("pages.acceptAllLanguages")
                }
            }
            FlowLayout(spacing: Spacing.xSmall, lineSpacing: Spacing.xSmall) {
                ForEach(languages) { language in
                    ProductPageLanguageChip(language: language, isSelected: language.code == viewModel.localeCode) {
                        viewModel.localeCode = language.code
                    }
                    .accessibilityIdentifier("pages.language.\(language.code)")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.languageBar")
    }
}
