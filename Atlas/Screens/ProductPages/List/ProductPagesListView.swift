//
//  ProductPagesListView.swift
//  Atlas
//

import SwiftUI

/// Board 50: the header (the count of 70; New Page… is in the toolbar), what
/// stops changes (the limit, offline, a key that can't change pages), the
/// suggested pages, and the table: the default page first as the
/// reference, then every page with its status and numbers.
struct ProductPagesListView: View {
    @Bindable var viewModel: ProductPagesViewModel
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ProductPagesListHeader(viewModel: viewModel)
                .padding(.horizontal, Spacing.xLarge)
                .padding(.top, Spacing.small)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.list")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProductPagesLoadingView(appName: viewModel.app.name)
                .padding(.horizontal, Spacing.xLarge)
            Spacer(minLength: 0)
        case let .failed(message):
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the custom product pages"), message: message, isInline: true) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
                .accessibilityIdentifier("pages.error.retry")
            }
            .padding(.horizontal, Spacing.xLarge)
            .accessibilityIdentifier("pages.error.load")
            Spacer(minLength: 0)
        case .loaded where viewModel.pages.isEmpty && viewModel.pageSuggestions.isEmpty:
            // Board 74: the banners, then the empty state in the middle of
            // what's left; New Page… stays in the toolbar.
            ProductPagesListBanners(viewModel: viewModel)
                .padding(.horizontal, Spacing.xLarge)
            ProductPagesEmptyView(appName: viewModel.app.name)
                .padding(.horizontal, Spacing.xLarge)
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    ProductPagesListBanners(viewModel: viewModel)
                    if viewModel.pages.isEmpty {
                        ProductPageSuggestionsGroup(viewModel: viewModel, isCompact: isCompact)
                        ProductPagesEmptyView(appName: viewModel.app.name, size: .inline)
                    } else {
                        if !viewModel.pageSuggestions.isEmpty {
                            ProductPageSuggestionsGroup(viewModel: viewModel, isCompact: isCompact)
                        }
                        ProductPagesTable(viewModel: viewModel, isCompact: isCompact)
                    }
                }
                .padding(.horizontal, Spacing.xLarge)
                .padding(.bottom, Spacing.xLarge)
            }
            .leavesChatRoom()
            .accessibilityIdentifier("pages.scroll")
        }
    }
}
