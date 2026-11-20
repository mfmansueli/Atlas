//
//  PageShotsTile.swift
//  Atlas
//

import SwiftUI

/// One screenshot of a page's set, from its PNG: a tile that spins until
/// it's read, outlined in the accent color as the page's own, with an
/// orange mark when its caption doesn't fit.
struct PageShotsTile: View {
    let url: URL?
    let aspect: CGFloat
    let height: CGFloat
    var isOwn = true
    var overflows = false
    let label: String

    /// Width over height of a screenshot on `display`.
    static func aspect(_ display: ScreenshotDisplayType) -> CGFloat {
        let size = display.defaultPixelSize
        return CGFloat(size.width) / CGFloat(max(1, size.height))
    }

    @State private var image: CGImage?
    @State private var isLoading = true
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    ImageLoadingTile(isLoading: isLoading)
                }
            }
            .frame(width: height * aspect, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isOwn ? Palette.accent : Palette.separator2, lineWidth: isOwn ? 1.5 : 0.5)
            )
            if overflows {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.warningMark)
                    .padding(3)
                    .background(Palette.raised, in: Circle())
                    .padding(3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(overflows ? String(localized: "\(label), its caption doesn’t fit") : label))
        .accessibilityAddTraits(.isImage)
        .task(id: url) {
            guard let url else {
                isLoading = false
                return
            }
            isLoading = true
            image = await PageShotsThumbnailLoader.image(at: url, maxPixel: Int(height * max(2, displayScale)))
            isLoading = false
        }
    }
}
