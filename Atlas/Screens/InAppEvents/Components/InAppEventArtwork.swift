//
//  InAppEventArtwork.swift
//  Atlas
//

import SwiftUI

/// An event's card image, a spinner on the event's own gradient while it
/// downloads; before one is uploaded (or if it can't be downloaded), the
/// gradient alone, so events are told apart at a glance.
struct InAppEventArtwork: View {
    let event: InAppEvent
    var cornerRadius: CGFloat = 9

    var body: some View {
        ZStack {
            LinearGradient(colors: Self.colors(for: event), startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url = event.media(.card)?.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error == nil {
                        ImageLoadingTile(systemImage: nil, fill: .clear)
                    }
                }
            } else {
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
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
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
