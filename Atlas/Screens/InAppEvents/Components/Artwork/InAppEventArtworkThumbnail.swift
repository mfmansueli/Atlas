//
//  InAppEventArtworkThumbnail.swift
//  Atlas
//

import SwiftUI

/// A small picture of an event card or details page file on this Mac: the
/// image, or a video's first frame with a play mark. A spinner while it's
/// read, a glyph when it can't be.
struct InAppEventArtworkThumbnail: View {
    let path: String
    let isVideo: Bool
    var height: CGFloat = 54

    @State private var phase = ImageLoadPhase.loading

    var body: some View {
        let aspect: CGFloat = phase.image.map { CGFloat($0.width) / CGFloat(max(1, $0.height)) } ?? 16 / 9
        ZStack {
            if let image = phase.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                ImageLoadingTile(isLoading: phase.isLoading, systemImage: isVideo ? "film" : "photo", controlSize: .mini)
            }
            if isVideo, phase.image != nil {
                Image(systemName: "play.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white, .black.opacity(0.45))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: height * aspect, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isVideo ? "Video" : "Image"))
        .task(id: path) {
            phase = .loading
            let url = URL(fileURLWithPath: path)
            let still = await InAppEventArtworkInspector.thumbnail(url, isVideo: isVideo, maxPixel: Int(height * 4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { phase = ImageLoadPhase(finished: still) }
        }
    }
}
