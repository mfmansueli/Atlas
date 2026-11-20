//
//  ProductPageStorePreview.swift
//  Atlas
//

import SwiftUI

/// "On the App Store", beside the editor: the default page and this page
/// side by side in the editor's language, with what's different outlined.
/// A suggested text shows in place before it's accepted, and says so; the
/// page's own screenshots waiting in Review & Push show as its own.
struct ProductPageStorePreview: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        let suggestion = viewModel.textSuggestion.flatMap { $0.isRefused ? nil : $0 }
        let ownText = viewModel.text(of: page, locale: locale)
        let pageText = ownText.isEmpty ? suggestion?.text ?? "" : ownText
        let queued = viewModel.queuedScreenshots(of: page, locale: locale, device: viewModel.device)
        let isOwnShots = queued != nil || viewModel.hasOwnScreenshots(page, locale: locale, device: viewModel.device)
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text("On the App Store")
                    .font(.headline)
                Spacer(minLength: Spacing.small)
                Text(ProductPageChangeBuilder.localeName(locale))
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
            }
            HStack(alignment: .top, spacing: Spacing.small) {
                ProductPageStorePreviewColumn(
                    viewModel: viewModel, title: String(localized: "Default page"),
                    screenshots: viewModel.screenshots(viewModel.defaultScreenshotsKey(locale), device: viewModel.device),
                    text: viewModel.defaultText(locale), locale: locale
                )
                ProductPageStorePreviewColumn(
                    viewModel: viewModel, title: String(localized: "This page"),
                    screenshots: viewModel.shownScreenshots(of: page, locale: locale, device: viewModel.device),
                    text: pageText.isEmpty ? viewModel.defaultText(locale) : pageText, locale: locale,
                    outlinesScreenshots: isOwnShots, outlinesText: !pageText.isEmpty, queued: queued
                )
            }
            Text(note(suggestion: suggestion, ownText: ownText, isOwnShots: isOwnShots))
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.preview.note")
            Text("The name, subtitle, icon and description are the default page’s on every page.")
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.preview")
    }

    private func note(suggestion: ProductPageTextSuggestion?, ownText: String, isOwnShots: Bool) -> String {
        if ownText.isEmpty, suggestion != nil { return String(localized: "Shown with the suggested text, which isn’t accepted yet.") }
        if !ownText.isEmpty || isOwnShots { return String(localized: "What’s different from the default page is outlined.") }
        return String(localized: "In \(ProductPageChangeBuilder.localeName(locale)) this page looks the same as the default page.")
    }
}
