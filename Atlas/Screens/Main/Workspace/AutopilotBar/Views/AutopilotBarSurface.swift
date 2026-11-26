//
//  AutopilotBarSurface.swift
//  Atlas
//

import SwiftUI

/// The Autopilot bar's shape (board 80): a rounded Liquid Glass surface
/// over the page, which shows through it as it scrolls under (solid with
/// Reduce Transparency). Closed it holds the strip and the field; open, the conversation,
/// as tall as `openHeight`. It's anchored at its bottom, so it grows up
/// (`AutopilotBarOpening`). Its edge is purple while the assistant waits
/// for the person and amber when it stopped.
struct AutopilotBarSurface<Closed: View, Open: View>: View {
    let isOpen: Bool
    /// What the strip says: purple while the assistant waits for the
    /// person, amber when it stopped.
    var stripKind: AutopilotBarStrip.Kind?
    let openHeight: CGFloat
    @ViewBuilder let closed: () -> Closed
    @ViewBuilder let open: () -> Open

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
    }

    var body: some View {
        let opening = AutopilotBarOpening.style(reduceMotion: reduceMotion)
        VStack(spacing: 0) {
            if isOpen {
                open()
                    .transition(opening.contentTransition)
            } else {
                closed()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isOpen ? openHeight : nil, alignment: .bottom)
        .background { surface }
        .overlay { shape.strokeBorder(edgeColor, lineWidth: edgeWidth) }
        .clipShape(shape)
        .depth(.popover)
        .animation(opening.animation(opening: isOpen), value: isOpen)
        .animation(MotionTiming.base.animation, value: stripKind)
    }

    /// The system's Liquid Glass, so the page shows through; solid with
    /// Reduce Transparency.
    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            shape.fill(Palette.raised)
        } else {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        }
    }

    private var edgeColor: Color {
        switch stripKind {
        case .needsYou: Palette.aiFill
        case .stopped: Palette.warn
        case .working, .done, nil: contrast == .increased ? Palette.separator2 : Palette.separator
        }
    }

    private var edgeWidth: CGFloat {
        switch stripKind {
        case .needsYou: Metrics.autopilotBarNeedsYouBorder
        case .stopped: 1
        case .working, .done, nil: 0.5
        }
    }
}
