//
//  ProductPagesListHeader.swift
//  Atlas
//

import SwiftUI

/// The list's header: what custom product pages are, how many of Apple's
/// 70 the app uses, Suggest Pages and New Page…. Both are off at the limit,
/// offline, while reading and with a key that can't change pages; Suggest
/// Pages leaves the header under 900 points.
struct ProductPagesListHeader: View {
    @Bindable var viewModel: ProductPagesViewModel
    let isCompact: Bool

    var body: some View {
        SectionHeader(
            systemImage: AppWorkspaceSection.productPages.systemImage,
            tint: Palette.sectionProductPages,
            title: String(localized: "Custom Product Pages"),
            subtitle: String(localized: """
            Other versions of \(viewModel.app.name)’s App Store page, each with its own link, for an audience, a campaign or a \
            search.
            """)
        ) {
            if viewModel.state.value != nil {
                Pill(text: viewModel.countText, style: viewModel.isAtLimit ? .warning : .neutral)
                    .help(Text("Apple allows 70 custom product pages for each app"))
                    .accessibilityLabel(Text("\(viewModel.pageCount) of 70 pages. Apple allows 70 custom product pages for each app."))
                    .accessibilityIdentifier("pages.count")
            }
            if !isCompact, !viewModel.pages.isEmpty || viewModel.state.value == nil {
                ProductPagesAskButton(
                    app: viewModel.app, kind: .suggestPages, prompt: viewModel.suggestPagesPrompt, identifier: "pages.suggest"
                )
                .buttonBorderShape(.capsule)
                .disabled(!viewModel.canMakePages)
            }
            Button {
                viewModel.isNewPagePresented = true
            } label: {
                Label("New Page…", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!viewModel.canMakePages)
            .accessibilityIdentifier("pages.new")
        }
    }
}
