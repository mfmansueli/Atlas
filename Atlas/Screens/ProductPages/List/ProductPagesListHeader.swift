//
//  ProductPagesListHeader.swift
//  Atlas
//

import SwiftUI

/// The list's header: what custom product pages are and how many of
/// Apple's 70 the app uses. New Page… is the toolbar's page action
/// (board 80), off at the limit, offline, while reading and with a key that
/// can't change pages; Suggest Pages… is Autopilot's.
struct ProductPagesListHeader: View {
    @Bindable var viewModel: ProductPagesViewModel

    var body: some View {
        SectionHeader(
            subtitle: String(localized: """
            Other App Store pages for \(viewModel.app.name), each for an audience, campaign or search.
            """)
        ) {
            if viewModel.state.value != nil {
                Pill(text: viewModel.countText, style: viewModel.isAtLimit ? .warning : .neutral)
                    .help(Text("Apple allows 70 custom product pages for each app"))
                    .accessibilityLabel(Text("\(viewModel.pageCount) of 70 custom product pages allowed"))
                    .accessibilityIdentifier("pages.count")
            }
        }
    }
}
