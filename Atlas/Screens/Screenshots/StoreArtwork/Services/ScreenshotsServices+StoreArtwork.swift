//
//  ScreenshotsServices+StoreArtwork.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// By default no header or search artwork is read, and live images come
/// through `RemoteImageCache` like the screenshots.
extension ScreenshotsServices {
    func liveArtwork(for _: StoreApp, localizations _: [StoreLocale: String]) async throws -> LiveStoreArtworkSet {
        LiveStoreArtworkSet()
    }

    func liveArtworkImage(_ image: LiveArtworkImage, pixelWidth: Int) async -> CGImage? {
        guard let url = image.url(width: pixelWidth) else { return nil }
        return await RemoteImageCache.shared.image(for: url)
    }

    func keptLiveArtworkImage(_ image: LiveArtworkImage, pixelWidth: Int) -> CGImage? {
        image.url(width: pixelWidth).flatMap { RemoteImageCache.shared.cachedImage(for: $0) }
    }
}
