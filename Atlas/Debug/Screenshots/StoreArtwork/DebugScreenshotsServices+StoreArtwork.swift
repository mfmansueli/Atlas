//
//  DebugScreenshotsServices+StoreArtwork.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
import Foundation

/// Lumen's live header and search artwork in the scenes, drawn here instead
/// of downloaded.
extension DebugScreenshotsServices {
    func liveArtwork(for app: StoreApp, localizations _: [StoreLocale: String]) async throws -> LiveStoreArtworkSet {
        app.id == DebugFixtures.AppID.lumen ? storeArtwork : LiveStoreArtworkSet()
    }

    func liveArtworkImage(_ image: LiveArtworkImage, pixelWidth: Int) async -> CGImage? {
        if let liveImageDelay { try? await Task.sleep(for: liveImageDelay) }
        return DebugStoreArtwork.image(for: image, pixelWidth: pixelWidth)
    }

    func keptLiveArtworkImage(_ image: LiveArtworkImage, pixelWidth: Int) -> CGImage? {
        liveImageDelay == nil ? DebugStoreArtwork.image(for: image, pixelWidth: pixelWidth) : nil
    }
}
#endif
