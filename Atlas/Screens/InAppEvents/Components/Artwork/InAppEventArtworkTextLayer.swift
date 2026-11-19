//
//  InAppEventArtworkTextLayer.swift
//  Atlas
//

import SwiftUI

/// What the App Store lays over an event card or details page, without
/// the art: Apple's dark fade over the lower part, the badge, the event's
/// name and its description in white, and on the card the app's name with
/// Get. Drawn at `InAppEventArtworkOverlay.pointSize(for:)` times
/// `scale`, laid out again at that size rather than stretched, so the
/// text stays sharp over a still or a playing loop in the full-size
/// viewer.
struct InAppEventArtworkTextLayer: View {
    let kind: InAppEventMedia.Kind
    let texts: InAppEventArtworkOverlayTexts
    var scale: CGFloat = 1

    var body: some View {
        let base = InAppEventArtworkOverlay.pointSize(for: kind)
        let size = CGSize(width: base.width * scale, height: base.height * scale)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                stops: [.init(color: .black.opacity(0), location: 0), .init(color: .black.opacity(0.62), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: size.height * (kind == .card ? 0.62 : 0.5))
            VStack(alignment: .leading, spacing: (kind == .card ? 4 : 6) * scale) {
                if !texts.badge.isEmpty {
                    Text(texts.badge.uppercased())
                        .font(.system(size: (kind == .card ? 12 : 13) * scale, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Text(texts.name)
                    .font(.system(size: (kind == .card ? 30 : 32) * scale, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(texts.description)
                    .font(.system(size: (kind == .card ? 16 : 15) * scale))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(kind == .card ? 2 : 4)
                    .fixedSize(horizontal: false, vertical: true)
                if kind == .card {
                    appRow
                        .padding(.top, 10 * scale)
                }
            }
            .foregroundStyle(.white)
            .padding((kind == .card ? 24 : 20) * scale)
            .frame(maxWidth: size.width, alignment: .leading)
        }
        .frame(width: size.width, height: size.height, alignment: .bottomLeading)
        .environment(\.layoutDirection, texts.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: texts.locale))
    }

    private var appRow: some View {
        HStack(spacing: 10 * scale) {
            RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                .fill(.white.opacity(0.9))
                .frame(width: 32 * scale, height: 32 * scale)
                .overlay(
                    Text(String(texts.appName.prefix(1)))
                        .font(.system(size: 15 * scale, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                )
            Text(texts.appName)
                .font(.system(size: 14 * scale, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 8 * scale)
            Text("Get")
                .font(.system(size: 14 * scale, weight: .bold))
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 5 * scale)
                .background(.white.opacity(0.28), in: Capsule())
        }
    }
}
