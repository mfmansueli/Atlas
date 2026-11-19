//
//  RenderEventArtworkTool+Page.swift
//  Atlas
//

import Foundation

@MainActor
extension RenderEventArtworkTool {
    /// Renders `page` into a file and returns its id: a still PNG at the
    /// largest size Apple takes, or with `motion`, the page's CSS and SVG
    /// animation as a 20-second seamless loop at 30 fps (its last frame is
    /// its first), at the smallest size Apple takes, in a .mov. Nil when the
    /// still's PNG couldn't be written.
    func render(_ page: EventArtworkPage, motion: Bool) async throws -> String? {
        guard motion else {
            let render = try await still(of: page)
            guard let png = ScreenshotPNG.data(render.image) else { return nil }
            return try InAppEventArtworkFiles.save(
                png, fileName: page.stillName, appID: page.app.id, in: directory, origin: InAppEventArtworkOrigin(source: .page, name: page.stillName)
            )
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let draft = directory.appending(path: "loop-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: draft) }
        _ = try await ArtworkWebLoop.write(page.request, to: draft, frames: loopFrames, size: InAppEventArtworkRules.minimumSize(for: page.kind))
        let movie = try Data(contentsOf: draft)
        return try InAppEventArtworkFiles.save(
            movie, fileName: page.movieName, appID: page.app.id, in: directory, origin: InAppEventArtworkOrigin(source: .page, name: page.movieName)
        )
    }

    /// The still at 3840 × 2160 (or 2160 × 3840). When WebKit's page process
    /// ends on it twice, as moving pages full of blurred glows did on Alba
    /// (2026-11-18), it's drawn at 1920 × 1080, the smallest size Apple
    /// takes, which has a quarter of the pixels.
    func still(of page: EventArtworkPage) async throws -> ArtworkWebRender {
        do {
            return try await ArtworkWebRenderer.shared.render(page.request)
        } catch ArtworkWebError.rendererStopped {
            return try await ArtworkWebRenderer.shared.render(Self.smallerStill(page.request, kind: page.kind))
        }
    }

    /// `request` drawn and returned at the smallest size Apple takes.
    static func smallerStill(_ request: ArtworkWebRequest, kind: InAppEventMedia.Kind) -> ArtworkWebRequest {
        var smaller = request
        let size = InAppEventArtworkRules.minimumSize(for: kind)
        smaller.pixelWidth = size.width
        smaller.drawingScale = Double(size.width) / Double(max(1, request.pixelSize.width))
        return smaller
    }
}
