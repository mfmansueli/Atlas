//
//  InAppEventGalleryTile.swift
//  Atlas
//

import SwiftUI

/// One event in the gallery (board 40): its card as the App Store shows
/// it (the used concept's, else the event's, else its gradient) with the
/// primary language's text over it, "3 concepts ready" while concepts
/// wait, its name and status, its dates, and what it still needs.
struct InAppEventGalleryTile: View {
    let event: InAppEvent
    let status: InAppEventStatus
    let card: InAppEventArtSource
    let texts: InAppEventShownTexts
    let readyConcepts: Int?
    let dates: String
    let note: InAppEventTileNote
    let label: String
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                cardImage
                    .padding(.bottom, Spacing.xxSmall)
                HStack(spacing: Spacing.xSmall) {
                    Text(event.referenceName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Pill(text: status.title, style: status.pillStyle)
                        .fixedSize()
                }
                Text(dates)
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                Text(note.text)
                    .font(.footnote.weight(note.tone == .secondary ? .regular : .semibold))
                    .foregroundStyle(noteColor)
                    .lineLimit(2)
                    .accessibilityIdentifier("events.tile.note.\(event.id)")
            }
            .padding(.horizontal, Spacing.small)
            .padding(.top, Spacing.small)
            .padding(.bottom, 10)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.popover, style: .continuous)
                    .strokeBorder(contrast == .increased ? Palette.label : Palette.separator2, lineWidth: contrast == .increased ? 1 : 0.5)
            )
            .depth(isHovered ? .popover : .flat)
            .contentShape(RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("events.tile.\(event.id)")
    }

    private var noteColor: Color {
        switch note.tone {
        case .secondary: Palette.label2
        case .suggestion: Palette.ai
        case .warning: Palette.warn
        }
    }

    private var cardImage: some View {
        InAppEventArtwork(event: event, source: card, cornerRadius: Radius.card, maxPixel: 900)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                // Apple's fade, from 45% of the height down.
                GeometryReader { proxy in
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.size.height * 0.55)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    if let badge = event.badge {
                        Text(badge.title.uppercased())
                            .font(.footnote.weight(.bold))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(texts.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text(texts.shortDescription)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, 10)
                .environment(\.layoutDirection, texts.isRightToLeft ? .rightToLeft : .leftToRight)
            }
            .overlay(alignment: .topTrailing) {
                if let readyConcepts {
                    HStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "sparkles")
                            .font(.footnote.weight(.semibold))
                        Text(readyConcepts == 1 ? "1 concept ready" : "\(readyConcepts) concepts ready")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 7)
                    .padding(.trailing, 9)
                    .frame(height: 22)
                    .background(Palette.ai, in: Capsule())
                    .depth(.card)
                    .padding(Spacing.small)
                    .accessibilityIdentifier("events.tile.ready.\(event.id)")
                }
            }
    }
}
