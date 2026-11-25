//
//  AppStorePreviewSearchCard.swift
//  Atlas
//

import SwiftUI

/// "In search results" under the App Store preview: the app's row as
/// search shows it, then its search artwork, or screenshots 1–3 without
/// it, and a line saying which. A click opens Screenshots in that
/// language.
struct AppStorePreviewSearchCard: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    let model: AppStorePreviewModel
    let artwork: AppStorePreviewArtwork
    var onOpen: (() -> Void)?

    var body: some View {
        if let onOpen {
            Button(action: onOpen) { card.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .help(Text("Edit in Screenshots", comment: "kind:help"))
        } else {
            card
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("In search results", comment: "kind:section-title")
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label2)
            row
            if let content = artwork.searchContent {
                StoreArtworkImage(
                    services: services, app: app, content: content, width: Metrics.storePreviewSearchArtWidth,
                    height: (Metrics.storePreviewSearchArtWidth * 2 / 3).rounded()
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if artwork.search.state.isNotPushed {
                        Pill(text: String(localized: "Not pushed", comment: "kind:status"), style: .accent)
                            .fixedSize()
                            .padding(Spacing.small)
                    }
                }
                .accessibilityLabel(Text("Search results artwork", comment: "kind:label"))
                .accessibilityIdentifier("storePreview.search.artwork")
            } else {
                shots
            }
            Text(artwork.searchNote)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("storePreview.search.note")
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.content, in: shape)
        .overlay(shape.strokeBorder(Palette.separator2, lineWidth: 0.5))
        .environment(\.layoutDirection, model.locale.isRTL ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("In search results", comment: "kind:label"))
        .accessibilityIdentifier("storePreview.search")
    }

    private var row: some View {
        HStack(spacing: Spacing.small) {
            AppIconTile(name: app.name, icon: app.icon, size: Metrics.storePreviewSearchIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name.value.isEmpty ? app.name : model.name.value)
                    .atlasTextStyle(.headline)
                    .lineLimit(1)
                Text(model.subtitle.value)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(model.words.get)
                .atlasTextStyle(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.xxSmall)
                .background(Palette.fill2, in: Capsule())
        }
    }

    private var shots: some View {
        HStack(alignment: .top, spacing: Spacing.xSmall) {
            ForEach(artwork.searchShots, id: \.id) { shot in
                AppStorePreviewSearchShot(services: services, shot: shot, width: Metrics.storePreviewSearchShotWidth)
            }
            if artwork.searchShots.isEmpty {
                ForEach(0..<StoreArtworkRules.searchShotCount, id: \.self) { _ in
                    let width = Metrics.storePreviewSearchShotWidth
                    ImageLoadingTile(isLoading: false, systemImage: nil)
                        .frame(width: width, height: (width * PreviewShotsStrip.placeholderAspect).rounded())
                        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Search shows screenshots 1 to 3", comment: "kind:label"))
        .accessibilityIdentifier("storePreview.search.shots")
    }
}
