//
//  InAppEventArtwork.swift
//  Atlas
//

import SwiftUI

/// One of an event's images filling its frame: a file on this Mac (a
/// concept's, or art waiting in Review & Push; a loop plays muted on
/// repeat, `AutoplayingLoop`), the App Store's (a spinner on the event's
/// gradient while it downloads; a video plays muted on repeat over its
/// poster frame once `RemoteVideoCache` has it, `RemoteAutoplayingLoop`),
/// or before there's one the gradient alone with soft shapes, so events
/// are told apart at a glance.
struct InAppEventArtwork: View {
    let event: InAppEvent
    /// Nil: the event's card on the App Store.
    var source: InAppEventArtSource?
    var cornerRadius: CGFloat = 9
    /// The longest side a file is read at.
    var maxPixel = 1280

    @State private var phase = ImageLoadPhase.loading

    private var shown: InAppEventArtSource {
        source ?? event.media(.card).flatMap(InAppEventArtSource.init(remote:)) ?? .none
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: Self.colors(for: event), startPoint: .topLeading, endPoint: .bottomTrailing)
            switch shown {
            case let .file(path, isVideo):
                // A loop plays over its first frame, muted on repeat.
                AutoplayingLoop(url: isVideo ? URL(fileURLWithPath: path) : nil) { _ in
                    if let image = phase.image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else if phase.isLoading {
                        ImageLoadingTile(systemImage: nil, fill: .clear)
                    }
                }
            case let .remote(url):
                remoteImage(url)
            case let .remoteVideo(poster, video):
                // The App Store's clip over its poster frame, both
                // downloaded once for every place that shows them.
                RemoteAutoplayingLoop(url: video) { _ in
                    remoteImage(poster)
                }
            case .none, .withoutLink:
                // Soft shapes, so the card reads as artwork still to come.
                GeometryReader { proxy in
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: proxy.size.height, height: proxy.size.height)
                        .offset(x: proxy.size.width - proxy.size.height * 0.7, y: -proxy.size.height * 0.35)
                    Circle()
                        .fill(.white.opacity(0.13))
                        .frame(width: proxy.size.height * 0.6, height: proxy.size.height * 0.6)
                        .offset(x: proxy.size.width * 0.1, y: proxy.size.height * 0.65)
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: proxy.size.height * 0.35, height: proxy.size.height * 0.35)
                        .offset(x: proxy.size.width * 0.55, y: proxy.size.height * 0.2)
                }
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
        .task(id: shown) {
            guard case let .file(path, isVideo) = shown else { return }
            phase = .loading
            let still = await InAppEventArtworkInspector.thumbnail(URL(fileURLWithPath: path), isVideo: isVideo, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { phase = ImageLoadPhase(finished: still) }
        }
    }

    /// The App Store's image through `RemoteImageCache`; the gradient
    /// shows when there's none.
    private func remoteImage(_ url: URL?) -> some View {
        CachedRemoteImage(url: url, maxPixelSize: maxPixel) { phase in
            if let image = phase.image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else if phase.isLoading {
                ImageLoadingTile(systemImage: nil, fill: .clear)
            }
        }
    }

    /// Two colors picked by the event's badge, shifted by its id.
    static func colors(for event: InAppEvent) -> [Color] {
        let palettes: [[UInt32]] = [
            [0x1B2A6B, 0x3E5BD8, 0x9CC3FF], [0xFF9A6B, 0xE0607E, 0x9A4FD0], [0xF7C548, 0xE07A2E, 0xE07A2E],
            [0x1F8A70, 0x35C2A0, 0xBDF2D5], [0x5B2A86, 0x8E54E9, 0xD9B8FF], [0x0F4C81, 0x2A9DF4, 0xA7E0FF],
        ]
        let seed = event.id.unicodeScalars.reduce(event.badge.map { InAppEventBadge.allCases.firstIndex(of: $0) ?? 0 } ?? 0) { ($0 &+ Int($1.value)) % 9973 }
        return palettes[seed % palettes.count].map { hex in
            Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
        }
    }
}
