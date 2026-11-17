//
//  InAppEventArtworkOverlayRenderer.swift
//  Atlas
//

import SwiftUI

/// Draws `InAppEventArtworkOverlay` offscreen at twice its point size, for
/// `render_event_artwork` and the media card.
@MainActor
enum InAppEventArtworkOverlayRenderer {
    static func render(_ image: CGImage, kind: InAppEventMedia.Kind, texts: InAppEventArtworkOverlayTexts, scale: CGFloat = 2) -> CGImage? {
        let renderer = ImageRenderer(content: InAppEventArtworkOverlay(image: image, kind: kind, texts: texts))
        renderer.scale = scale
        renderer.isOpaque = kind == .details
        return renderer.cgImage
    }
}
