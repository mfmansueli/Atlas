//
//  StoreArtworkSearchShots.swift
//  Atlas
//

import SwiftUI

/// What search shows without search artwork: the language's screenshots
/// 1–3 on iPhone, small and side by side.
struct StoreArtworkSearchShots: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: String
    let width: CGFloat

    var body: some View {
        let items = viewModel.searchFallbackItems(locale: locale)
        let size = viewModel.pixelSize(for: .iPhone)
        let height = (width * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
        HStack(spacing: Spacing.xSmall) {
            ForEach(items) { item in
                Group {
                    if let image = viewModel.thumbnail(for: item.cell) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    } else {
                        ImageLoadingTile(isLoading: viewModel.isRendering(item.cell), systemImage: nil, controlSize: .mini)
                    }
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
            }
        }
        .environment(\.layoutDirection, StoreLocaleCatalog.locale(code: locale)?.isRTL == true ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Search shows screenshots 1 to 3", comment: "kind:label"))
        .accessibilityIdentifier("screenshots.artwork.search.shots")
    }
}
