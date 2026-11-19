//
//  InAppEventPreviewArtButton.swift
//  Atlas
//

import SwiftUI

/// The art in the event's preview as a button that opens it full size,
/// with the zoom badge at the top right on hover or keyboard focus (always
/// with Increase Contrast).
struct InAppEventPreviewArtButton<Content: View>: View {
    let label: String
    let cornerRadius: CGFloat
    let identifier: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            content()
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.black.opacity(0.42), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(Spacing.small)
                        .opacity(isHovered || isFocused || contrast == .increased ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered || isFocused)
                        .accessibilityHidden(true)
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .pointerStyle(.zoomIn)
        .help("View full size  Space")
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }
}
