//
//  StoreArtworkSection.swift
//  Atlas
//

import SwiftUI

/// The top of a language's Screenshots page (board 78): the product page
/// header and the search results artwork, optional, side by side at the
/// same height, one under the other when the column is too narrow. The
/// tiles wrap by the width they're offered (`FlowLayout`), never by one
/// measured after the fact: a measured width held the side-by-side tiles
/// (603 pt) and pushed the page wider than the window.
struct StoreArtworkSection: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

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
            FlowLayout(spacing: Spacing.medium) { tiles }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, locale.isRTL ? .rightToLeft : .leftToRight)
        .task(id: viewModel.liveArtworkKey) { await viewModel.loadLiveArtwork() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.artwork")
    }

    private var tiles: some View {
        ForEach(StoreArtworkPlace.allCases, id: \.self) { place in
            StoreArtworkTileView(viewModel: viewModel, slot: viewModel.storeArtworkSlot(place, locale: locale.code), localeName: locale.name)
        }
    }
}
