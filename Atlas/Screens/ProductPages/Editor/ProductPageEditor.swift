//
//  ProductPageEditor.swift
//  Atlas
//

import SwiftUI

/// Board 51: one page. Its header (back, name, status, what isn't
/// pushed, Discard…, Delete…, Push and Submit…), where it stands with App
/// Review, its link and deep link, the language bar, the promotional text,
/// the search keywords and the screenshots, with the App Store's view of
/// it beside them when there's room.
struct ProductPageEditor: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let isCompact: Bool
    let onReviewPush: (ProductPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ProductPageEditorHeader(viewModel: viewModel, page: page, isCompact: isCompact, onReviewPush: onReviewPush)
                .padding(.horizontal, Spacing.xLarge)
                .padding(.top, Spacing.small)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    ProductPageStatusBanner(viewModel: viewModel, page: page)
                    if viewModel.isPreparingNewVersion(page) {
                        ProductPageVersionCompare(viewModel: viewModel, page: page, locale: viewModel.localeCode)
                    }
                    HStack(alignment: .top, spacing: Spacing.large) {
                        fields
                        if !isCompact {
                            ProductPageStorePreview(viewModel: viewModel, page: page, locale: viewModel.localeCode)
                                .frame(width: 300)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xLarge)
                .padding(.bottom, Spacing.xLarge)
            }
            .accessibilityIdentifier("pages.editor.scroll")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: "\(page.id).\(viewModel.localeCode)") {
            await viewModel.loadScreenshots(of: page, locale: viewModel.localeCode)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.editor")
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ProductPageLinkCard(viewModel: viewModel, page: page)
            ProductPageLanguageBar(viewModel: viewModel, page: page)
            ProductPagePromoBox(viewModel: viewModel, page: page, locale: viewModel.localeCode)
            ProductPageKeywordsBox(viewModel: viewModel, page: page, locale: viewModel.localeCode)
            ProductPageScreenshotsBox(viewModel: viewModel, page: page, locale: viewModel.localeCode)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
