//
//  InAppEventArtworkThumbnailFill.swift
//  Atlas
//

import SwiftUI

/// An event image file on this Mac filling its frame (a video plays muted
/// on repeat over its first frame): a spinner while it's read, a glyph
/// when it can't be.
struct InAppEventArtworkThumbnailFill: View {
    let path: String
    let isVideo: Bool
    var maxPixel = 480

    @State private var phase = ImageLoadPhase.loading

    var body: some View {
        AutoplayingLoop(url: isVideo ? URL(fileURLWithPath: path) : nil) { _ in
            Palette.fill2
            if let image = phase.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                ImageLoadingTile(isLoading: phase.isLoading, systemImage: isVideo ? "film" : "photo", controlSize: .mini)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .task(id: path) {
            phase = .loading
            let still = await InAppEventArtworkInspector.thumbnail(URL(fileURLWithPath: path), isVideo: isVideo, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { phase = ImageLoadPhase(finished: still) }
        }
    }
}
