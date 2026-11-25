//
//  StoreArtworkTileView.swift
//  Atlas
//

import SwiftUI

/// The header or the search artwork of one language: the image (or what
/// Apple shows without one: a dashed box saying the page starts with the
/// icon and name, or screenshots 1–3), its name and size, its state pill
/// and its Add ▾ or Edit ▾ button. What's not pushed has the blue
/// outline; what's to be deleted is dimmed.
struct StoreArtworkTileView: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let slot: StoreArtworkSlot
    let localeName: String

    private var place: StoreArtworkPlace { slot.place }

    private var width: CGFloat {
        place == .header ? Metrics.storeArtworkHeaderWidth : Metrics.storeArtworkSearchWidth
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            frame
            caption
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.artwork.\(place.rawValue)")
    }

    @ViewBuilder
    private var frame: some View {
        let height = Metrics.storeArtworkTileHeight
        Group {
            switch slot.content {
            case .noHeader:
                StoreArtworkEmptyHeader()
            case .searchShots:
                StoreArtworkSearchShots(viewModel: viewModel, locale: slot.locale, width: Metrics.storeArtworkFallbackShotWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.fill2, in: shape)
            case .live, .file:
                StoreArtworkImage(services: viewModel.services, app: viewModel.app, content: slot.content, width: width, height: height)
                    .clipShape(shape)
                    .opacity(slot.state == .willBeDeleted ? 0.45 : 1)
                    .overlay {
                        if slot.state == .willBeDeleted { StoreArtworkDeletedMark() }
                    }
            }
        }
        .frame(width: width, height: height)
        .overlay {
            switch slot.content {
            case .noHeader, .searchShots: EmptyView()
            case .live, .file:
                shape.strokeBorder(slot.state.isNotPushed ? Palette.accent : Palette.separator2, lineWidth: slot.state.isNotPushed ? 2.5 : 0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(slot.accessibilityLabel(localeName: localeName)))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("screenshots.artwork.\(place.rawValue).image")
    }

    private var caption: some View {
        HStack(spacing: Spacing.xSmall) {
            VStack(alignment: .leading, spacing: 1) {
                Text(place.title)
                    .atlasTextStyle(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(place.spec)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Pill(text: slot.state.title(for: place), style: slot.state.pillStyle)
                .fixedSize()
                .accessibilityIdentifier("screenshots.artwork.\(place.rawValue).state")
            StoreArtworkMenuButton(viewModel: viewModel, slot: slot, localeName: localeName)
        }
    }
}
