//
//  ProductPageSuggestionDetails.swift
//  Atlas
//

import SwiftUI

/// What a suggested page holds: its keywords, its promotional text in the
/// primary language (and how many languages it's written in), what its
/// screenshots should show first, and its deep link.
struct ProductPageSuggestionDetails: View {
    @Bindable var viewModel: ProductPagesViewModel
    let suggestion: ProductPageSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.small) {
                let locales = suggestion.keywordLocales(primary: viewModel.primaryLocale)
                if !locales.isEmpty {
                    GridRow {
                        label("Keywords")
                        keywords(locales)
                    }
                }
                let text = suggestion.promotionalText(primary: viewModel.primaryLocale)
                if !text.isEmpty {
                    GridRow {
                        label("Promotional text")
                        Text("\(text) \(Text(writtenIn).foregroundStyle(Palette.label2))")
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !suggestion.screens.isEmpty {
                    GridRow {
                        label("Screenshots")
                        Text(suggestion.screens)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !suggestion.deepLink.isEmpty {
                    GridRow {
                        label("Deep link")
                        Text(verbatim: suggestion.deepLink)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            refused
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.suggestion.\(suggestion.id).details")
    }

    /// The texts Atlas stopped, each with the words App Review would reject
    /// marked: they stay out of the draft.
    @ViewBuilder
    private var refused: some View {
        let texts = suggestion.notOfferedTexts ?? []
        if !texts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(texts.count == 1
                    ? "No text offered: that language keeps the default page’s."
                    : "No texts offered: those languages keep the default page’s.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(texts) { text in
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text(ProductPageChangeBuilder.localeName(text.locale))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.label2)
                        ProductPageRefusedTextCard(
                            app: viewModel.app, suggestion: text, pageName: suggestion.name,
                            askPrompt: viewModel.askForAnotherPrompt(text, in: suggestion)
                        )
                    }
                }
            }
        }
    }

    /// The primary language's keywords, and how many languages choose
    /// some; a page for other markets (none in the primary language) lists
    /// each language's, so “bom dia” shows on a page for Brazil.
    @ViewBuilder
    private func keywords(_ locales: [String]) -> some View {
        let primary = viewModel.primaryLocale
        if locales.first == primary {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                pills(suggestion.keywords[primary] ?? [])
                if locales.count > 1 {
                    Text("Chosen in \(locales.count) languages.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                ForEach(locales, id: \.self) { locale in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        Text(ProductPageChangeBuilder.localeName(locale))
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .fixedSize()
                        pills(suggestion.keywords[locale] ?? [])
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func pills(_ keywords: [String]) -> some View {
        FlowLayout(spacing: Spacing.xxSmall, lineSpacing: Spacing.xxSmall) {
            ForEach(keywords, id: \.self) { keyword in
                Pill(text: keyword, style: .neutral)
            }
        }
    }

    private func label(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.label2)
            .frame(width: 112, alignment: .leading)
    }

    /// "Written in all 12 languages."
    private var writtenIn: String {
        let count = suggestion.promotionalTexts.values.filter { !$0.isEmpty }.count
        if count <= 1 { return "" }
        if count >= viewModel.defaultPage.languages.count, count > 1 { return String(localized: "Written in all \(count) languages.") }
        return String(localized: "Written in \(count) languages.")
    }
}
