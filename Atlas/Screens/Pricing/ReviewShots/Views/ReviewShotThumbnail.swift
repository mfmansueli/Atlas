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

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                ImageLoadingTile(isLoading: isLoading)
                    .frame(width: width, height: width * 2.165)
            }
        }
        .frame(width: width)
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
