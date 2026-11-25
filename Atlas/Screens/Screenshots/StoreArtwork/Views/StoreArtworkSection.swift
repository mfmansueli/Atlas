//
//  StoreArtworkSection.swift
//  Atlas
//

import SwiftUI

/// The top of a language's Screenshots page (board 78): the product page
/// header and the search results artwork, optional, side by side at the
/// same height, one under the other when the column is too narrow.
struct StoreArtworkSection: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    /// Nil until measured: side by side on the first frame.
    @State private var columnWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text("Header and search artwork", comment: "kind:section-title")
                    .atlasTextStyle(.headline)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Optional. Where Apple shows them; without them the page starts with the name and search shows screenshots 1–3.",
                    comment: "kind:label"
                )
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            if stacks {
                VStack(alignment: .leading, spacing: Spacing.medium) { tiles }
            } else {
                HStack(alignment: .top, spacing: Spacing.medium) { tiles }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { columnWidth = $0 })
        .environment(\.layoutDirection, locale.isRTL ? .rightToLeft : .leftToRight)
        .task(id: viewModel.liveArtworkKey) { await viewModel.loadLiveArtwork() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.artwork")
    }

    private var stacks: Bool {
        columnWidth.map(StoreArtworkRules.stacksArtwork(columnWidth:)) ?? false
    }

    private var tiles: some View {
        ForEach(StoreArtworkPlace.allCases, id: \.self) { place in
            StoreArtworkTileView(viewModel: viewModel, slot: viewModel.storeArtworkSlot(place, locale: locale.code), localeName: locale.name)
        }
    }
}
