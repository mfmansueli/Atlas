//
//  ReviewShotThumbnail.swift
//  Atlas
//

import ImageIO
import SwiftUI

/// A review screenshot's image, read from its kept file off the main
/// thread: a tile with a spinner until then, a bare tile when it can't be
/// read. Phone-shaped by default.
struct ReviewShotThumbnail: View {
    let url: URL
    var width: CGFloat = 56
    /// What it shows, for VoiceOver.
    var label: String

    @State private var image: CGImage?
    @State private var isLoading = true

    /// The image's own proportions, phone-shaped until it's read.
    var height: CGFloat {
        guard let image, image.width > 0 else { return width * Self.phoneRatio }
        return (width * CGFloat(image.height) / CGFloat(image.width)).rounded()
    }

    /// An iPhone 17 Pro screen's height over its width.
    static let phoneRatio: CGFloat = 2.165

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                ImageLoadingTile(isLoading: isLoading)
            }
        }
        // Its height too: with only a width, a row that offers less height
        // squeezed it (Bruma's Yearly card drew a 64 × 50 pt box with a
        // tiny image in it).
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isImage)
        .task(id: url) {
            isLoading = true
            let url = url
            image = await Task.detached {
                CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            }.value
            isLoading = false
        }
    }
}
