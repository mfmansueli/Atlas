//
//  ProductPagePromoBox.swift
//  Atlas
//

import SwiftUI

/// The page's promotional text in one language: above the description,
/// the only words a page can change. Empty, it shows the default page's.
/// A suggestion waits under it; one Atlas stopped shows why.
struct ProductPagePromoBox: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        let text = viewModel.text(of: page, locale: locale)
        let suggestion = viewModel.textSuggestion
        let isRTL = StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        let isOver = text.count > ProductPageField.promotionalTextLimit
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                if isPending { UnsavedDot(size: 6) }
                Text("Promotional text")
                    .font(.body.weight(.semibold))
                Text("Above the description. The only words a page can change.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                counter(text.count, isOver: isOver)
            }
            TextField(
                "Promotional text",
                text: Binding { viewModel.text(of: page, locale: locale) } set: { viewModel.editText($0) },
                prompt: Text("Same as the default page"),
                axis: .vertical
            )
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .font(.callout)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(Palette.content, in: shape)
            .overlay(shape.strokeBorder(isOver ? Palette.err : Palette.separator2, lineWidth: isOver ? 1.5 : 1))
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .disabled(!viewModel.canEdit(page))
            .accessibilityLabel(Text("Promotional text, \(ProductPageChangeBuilder.localeName(locale))"))
            .accessibilityIdentifier("pages.promo")
            if text.isEmpty, suggestion == nil {
                Text("\(ProductPageChangeBuilder.localeName(locale)): default page’s promotional text. Write one for this page.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.promo.empty")
            }
            let issues = StoreTextGuidelineCheck.issues(in: text, for: ListingField.promotionalText)
            if !issues.isEmpty {
                InlineMessage.warning(issues.map(\.message).joined(separator: "\n"))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.promo.guideline")
            }
            if let suggestion {
                if suggestion.isRefused {
                    ProductPageRefusedTextCard(
                        app: viewModel.app, suggestion: suggestion, pageName: page.name, askPrompt: viewModel.askForAnotherPrompt(suggestion)
                    )
                } else {
                    ProductPageTextSuggestionCard(viewModel: viewModel, suggestion: suggestion, current: text, isRightToLeft: isRTL)
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.promoBox")
    }

    private var isPending: Bool {
        !page.isDraft && viewModel.edits(of: page).texts[locale] != nil
    }

    @ViewBuilder
    private func counter(_ count: Int, isOver: Bool) -> some View {
        let label = "\(count) / \(ProductPageField.promotionalTextLimit)"
        if isOver {
            Pill(text: label, style: .danger)
                .accessibilityIdentifier("pages.promo.counter")
        } else {
            Text(label)
                .font(.footnote.monospaced())
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("pages.promo.counter")
        }
    }
}
