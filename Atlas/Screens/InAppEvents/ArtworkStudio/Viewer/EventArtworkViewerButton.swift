//
//  EventArtworkViewerButton.swift
//  Atlas
//

import SwiftUI

/// A button on the viewer's black: a round one for a glyph (close, the
/// arrows, full screen) or a capsule with a title; brighter on hover, a
/// white ring with Increase Contrast.
struct EventArtworkViewerButton: View {
    enum Shape {
        case circle(CGFloat)
        case capsule
    }

    var title: String?
    var systemImage: String?
    var shape: Shape = .capsule
    var isProminent = false
    let label: String
    let help: String
    let identifier: String
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(.white)
                .background(fill, in: Capsule())
                .overlay {
                    if contrast == .increased { Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1) }
                }
                .contentShape(Capsule())
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var content: some View {
        switch shape {
        case let .circle(size):
            Image(systemName: systemImage ?? "xmark")
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
        case .capsule:
            HStack(spacing: Spacing.xxSmall) {
                if let systemImage { Image(systemName: systemImage).font(.subheadline.weight(.semibold)) }
                if let title { Text(title).font(.callout.weight(.medium)) }
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
        }
    }

    private var fill: Color {
        if isProminent { return isHovered ? EventArtworkViewerStyle.useHover : EventArtworkViewerStyle.use }
        return EventArtworkViewerStyle.control(isHovered)
    }
}
