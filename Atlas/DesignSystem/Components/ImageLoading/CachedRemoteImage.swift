//
//  CachedRemoteImage.swift
//  Atlas
//

import SwiftUI

/// An image from the internet (or a file on this Mac) through
/// `RemoteImageCache`, in place of `AsyncImage`: one seen before draws in
/// the first frame, without a spinner; `content` gets the phase so the
/// place shows `ImageLoadingTile` while it's on its way.
struct CachedRemoteImage<Content: View>: View {
    let url: URL?
    /// The longest side it's decoded at; nil as it is.
    var maxPixelSize: Int?
    var cache = RemoteImageCache.shared
    @ViewBuilder let content: (ImageLoadPhase) -> Content

    @State private var phase: ImageLoadPhase?

    var body: some View {
        content(phase ?? initialPhase)
            .task(id: url) {
                guard let url else {
                    phase = .unavailable
                    return
                }
                if let kept = cache.cachedImage(for: url, maxPixelSize: maxPixelSize) {
                    phase = .loaded(kept)
                    return
                }
                phase = .loading
                let image = await cache.image(for: url, maxPixelSize: maxPixelSize)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { phase = ImageLoadPhase(finished: image) }
            }
    }

    /// Before the task runs: the image if it's in memory, so it draws at
    /// once; nothing to load without an address.
    private var initialPhase: ImageLoadPhase {
        guard let url else { return .unavailable }
        return cache.cachedImage(for: url, maxPixelSize: maxPixelSize).map(ImageLoadPhase.loaded) ?? .loading
    }
}
