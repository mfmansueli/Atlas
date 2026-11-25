//
//  HelpPictureRing.swift
//  Atlas
//

import SwiftUI

/// The orange ring a Help picture draws around what to click
/// (README-Welcome): a 2 pt ring with a soft halo outside it, drawn over
/// the thing without moving it. A word in the ring turns semibold, as the
/// design draws it; a filled button keeps a gap in the page's colour.
struct HelpPictureRing: ViewModifier {
    enum Outline {
        /// A word or a value: the ring leaves a little room around it.
        case word
        /// A field: the ring hugs its edge.
        case field
        /// A round filled button.
        case button
    }

    let outline: Outline
    let isOn: Bool

    func body(content: Content) -> some View {
        if !isOn {
            content
        } else if outline == .word {
            content
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label)
                .overlay { ring }
        } else {
            content.overlay { ring }
        }
    }

    private var ring: some View {
        ZStack {
            if gap > 0 {
                layer(Palette.content, width: gap, outset: gap)
            }
            layer(Palette.helpRing, width: Metrics.helpRingWidth, outset: gap + Metrics.helpRingWidth)
            layer(Palette.helpRingHalo, width: Metrics.helpRingHaloWidth, outset: gap + Metrics.helpRingWidth + Metrics.helpRingHaloWidth)
        }
        .allowsHitTesting(false)
    }

    /// One band of the ring, `outset` past the thing's edge.
    private func layer(_ color: Color, width: CGFloat, outset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius + outset, style: outline == .button ? .circular : .continuous)
            .strokeBorder(color, lineWidth: width)
            .padding(.horizontal, -(room.width + outset))
            .padding(.vertical, -(room.height + outset))
    }

    /// The room between the thing and the ring's inside.
    private var room: CGSize {
        outline == .word ? CGSize(width: Spacing.xxSmall, height: Spacing.tiny) : .zero
    }

    private var gap: CGFloat {
        outline == .button ? Metrics.helpRingGap : 0
    }

    /// The corner at the ring's inside.
    private var cornerRadius: CGFloat {
        switch outline {
        case .word: Radius.menuRow
        case .field: Radius.badge
        case .button: Metrics.helpPictureAddButton / 2
        }
    }
}

extension View {
    /// Rings what a Help picture's step says to click; see `HelpPictureRing`.
    func helpPictureRing(_ outline: HelpPictureRing.Outline = .word, isOn: Bool = true) -> some View {
        modifier(HelpPictureRing(outline: outline, isOn: isOn))
    }
}
