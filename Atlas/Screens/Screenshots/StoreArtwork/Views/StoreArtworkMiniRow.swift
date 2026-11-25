//
//  StoreArtworkMiniRow.swift
//  Atlas
//

import SwiftUI

/// All Languages: a language's header and search artwork, small, before its
/// screenshots; "No header" and "1–3" where there's none.
struct StoreArtworkMiniRow: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            mini(.header, width: Metrics.storeArtworkMiniHeaderWidth, none: String(localized: "No header", comment: "kind:label"))
            mini(.search, width: Metrics.storeArtworkMiniSearchWidth, none: String(localized: "1–3", comment: "kind:label"))
        }
        .task(id: viewModel.liveArtworkKey) { await viewModel.loadLiveArtwork() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("screenshots.page.allLanguages.artwork.\(locale.code)")
    }

    @ViewBuilder
    private func mini(_ place: StoreArtworkPlace, width: CGFloat, none: String) -> some View {
        let slot = viewModel.storeArtworkSlot(place, locale: locale.code)
        let height = Metrics.storeArtworkMiniHeight
        let shape = RoundedRectangle(cornerRadius: Radius.flag, style: .continuous)
        if let content = slot.storeContent {
            StoreArtworkImage(services: viewModel.services, app: viewModel.app, content: content, width: width, height: height)
                .clipShape(shape)
                .overlay(shape.strokeBorder(slot.state.isNotPushed ? Palette.accent : Palette.separator2, lineWidth: slot.state.isNotPushed ? 1.5 : 0.5))
                .help(Text(place.title))
        } else {
            Text(none)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label3)
                .frame(width: width, height: height)
                .overlay(shape.strokeBorder(Palette.separator2, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                .help(Text(place == .header ? place.deleteNote : place.noneTitle))
        }
    }

    /// "Header: Live. Search results artwork: Uses screenshots 1–3."
    private var accessibilityText: String {
        StoreArtworkPlace.allCases.map { place in
            let slot = viewModel.storeArtworkSlot(place, locale: locale.code)
            return "\(place.title): \(slot.state.title(for: place))"
        }
        .joined(separator: ". ")
    }
}
