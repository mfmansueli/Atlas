//
//  ProductPagesListHeader.swift
//  Atlas
//

import SwiftUI

/// The list's header: what custom product pages are, how many of Apple's
/// 70 the app uses, and New Page…, off at the limit, offline, while
/// reading and with a key that can't change pages. Suggest Pages… is the
/// toolbar's Autopilot (board 57).
struct ProductPagesListHeader: View {
    @Bindable var viewModel: ProductPagesViewModel

    var body: some View {
        SectionHeader(
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
