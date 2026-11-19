//
//  InAppEventArtworkOverlay.swift
//  Atlas
//

import SwiftUI

/// An event card or details page as the App Store lays it out: the art,
/// then Apple's fade and text over its lower part
/// (`InAppEventArtworkTextLayer`). It's how the art reads under the text,
/// not a pixel copy of Apple's layout.
struct InAppEventArtworkOverlay: View {
    let image: CGImage
    let kind: InAppEventMedia.Kind
    let texts: InAppEventArtworkOverlayTexts

    /// The card at 640 × 360 points, the details page at 360 × 640.
    static func pointSize(for kind: InAppEventMedia.Kind) -> CGSize {
        kind == .card ? CGSize(width: 640, height: 360) : CGSize(width: 360, height: 640)
    }

    var body: some View {
        let size = Self.pointSize(for: kind)
        ZStack(alignment: .bottomLeading) {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            InAppEventArtworkTextLayer(kind: kind, texts: texts)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: kind == .card ? 14 : 0, style: .continuous))
    }
}
