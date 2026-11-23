//
//  EventArtworkPanelPair.swift
//  Atlas
//

import SwiftUI

/// The event's card and details image side by side in the Artwork panel,
/// 118 points tall: each opens full size. A missing one is an amber "!".
struct EventArtworkPanelPair: View {
    let card: InAppEventArtSource
    let details: InAppEventArtSource
    let event: InAppEvent
    let onOpen: (InAppEventMedia.Kind) -> Void

    static let height: CGFloat = 118

    var body: some View {
        HStack(spacing: 6) {
            image(.card, source: card, width: Self.height * 16 / 9)
            image(.details, source: details, width: Self.height * 9 / 16)
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.art.pair")
    }

    @ViewBuilder
    private func image(_ kind: InAppEventMedia.Kind, source: InAppEventArtSource, width: CGFloat) -> some View {
        if source.exists {
            PairButton(kind: kind) {
                onOpen(kind)
            } content: {
                InAppEventArtwork(event: event, source: source, cornerRadius: Radius.field, maxPixel: 600)
                    .frame(width: width, height: Self.height)
            }
        } else {
            Text("!")
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.warn)
                .frame(width: width, height: Self.height)
                .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.warnMark, lineWidth: 1.5))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(kind == .card ? "Event card missing" : "Event details image missing"))
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("events.art.pair.missing.\(kind.mcpValue)")
        }
    }

    /// An image that opens full size, ringed in the accent on hover.
    private struct PairButton<Content: View>: View {
        let kind: InAppEventMedia.Kind
        let action: () -> Void
        @ViewBuilder let content: () -> Content

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                content()
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .strokeBorder(Palette.accent, lineWidth: 2)
                            .opacity(isHovered ? 1 : 0)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .pointerStyle(.zoomIn)
            .help(kind == .card ? "Event card · 1920 × 1080" : "Event details · 1080 × 1920")
            .accessibilityLabel(Text(kind == .card ? "Event card, view full size" : "Event details image, view full size"))
            .accessibilityIdentifier("events.art.pair.\(kind.mcpValue)")
        }
    }
}
