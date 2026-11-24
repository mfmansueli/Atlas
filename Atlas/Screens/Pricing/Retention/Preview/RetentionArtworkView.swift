//
//  RetentionArtworkView.swift
//  Atlas
//

import SwiftUI

/// A retention image, filling its frame: the sample art, a file on this
/// Mac, or the Asset Library's thumbnail, with a spinner while it loads.
struct RetentionArtworkView: View {
    let image: RetentionImage

    var body: some View {
        Group {
            if let sample = image.sampleArtwork {
                RetentionSampleArtwork(name: sample)
            } else if let url = image.localPath.map({ URL(fileURLWithPath: $0) }) ?? image.thumbnailURL(width: 320) {
                CachedRemoteImage(url: url) { phase in
                    if let loaded = phase.image {
                        Image(decorative: loaded, scale: 1).resizable().scaledToFill()
                    } else {
                        // A spinner while it downloads or is read.
                        ImageLoadingTile(isLoading: phase.isLoading)
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(Text(image.name))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Palette.fill2)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Palette.label3)
            }
    }
}
