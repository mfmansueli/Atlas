//
//  InAppEventArtworkOverlay.swift
//  Atlas
//

import SwiftUI

/// An event card or details page as the App Store lays it out: the art,
/// Apple's dark fade over its lower part, then the badge, the event's name
/// and its description (the short one on the card, the long one on the
/// details page) in white, and on the card the app's name with Get. It's
/// how the art reads under the text, not a pixel copy of Apple's layout.
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
            LinearGradient(
                stops: [.init(color: .black.opacity(0), location: 0), .init(color: .black.opacity(0.62), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: size.height * (kind == .card ? 0.62 : 0.5))
            VStack(alignment: .leading, spacing: kind == .card ? 4 : 6) {
                if !texts.badge.isEmpty {
                    Text(texts.badge.uppercased())
                        .font(.system(size: kind == .card ? 12 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Text(texts.name)
                    .font(.system(size: kind == .card ? 30 : 32, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(texts.description)
                    .font(.system(size: kind == .card ? 16 : 15))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(kind == .card ? 2 : 4)
                    .fixedSize(horizontal: false, vertical: true)
                if kind == .card {
                    appRow
                        .padding(.top, 10)
                }
            }
            .foregroundStyle(.white)
            .padding(kind == .card ? 24 : 20)
            .frame(maxWidth: size.width, alignment: .leading)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: kind == .card ? 14 : 0, style: .continuous))
        .environment(\.layoutDirection, texts.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: texts.locale))
    }

    private var appRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.9))
                .frame(width: 32, height: 32)
                .overlay(Text(String(texts.appName.prefix(1))).font(.system(size: 15, weight: .bold)).foregroundStyle(.black.opacity(0.7)))
            Text(texts.appName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("Get")
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(.white.opacity(0.28), in: Capsule())
        }
    }
}
