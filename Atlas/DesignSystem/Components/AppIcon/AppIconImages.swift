//
//  AppIconImages.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// App icons without their margin (`AppIconMargin`), trimmed once per
/// launch, so the sidebar, the overview and the Studio draw them straight
/// away after the first time. The files come through `RemoteImageCache`,
/// so after a relaunch they're read from disk. A failed download isn't
/// kept: the next tile that shows the icon tries again.
@MainActor
final class AppIconImages {
    static let shared = AppIconImages()

    private let fetch: @Sendable (URL) async throws -> Data
    private var images: [URL: CGImage] = [:]
    private var loads: [URL: Task<CGImage?, Never>] = [:]

    init(fetch: @escaping @Sendable (URL) async throws -> Data = { try await RemoteImageCache.shared.data(for: $0) }) {
        self.fetch = fetch
    }

    /// The icon if it has already been downloaded.
    func cached(_ url: URL) -> CGImage? {
        images[url]
    }

    /// The icon, downloading it unless it already was; tiles asking at the
    /// same time share one download.
    func image(for url: URL) async -> CGImage? {
        if let image = images[url] { return image }
        let load = loads[url] ?? Task.detached(priority: .utility) { [fetch] in
            guard let data = try? await fetch(url) else { return nil }
            return AppIconMargin.decodeTrimmed(data)
        }
        loads[url] = load
        let image = await load.value
        loads[url] = nil
        if let image { images[url] = image }
        return image
    }
}
