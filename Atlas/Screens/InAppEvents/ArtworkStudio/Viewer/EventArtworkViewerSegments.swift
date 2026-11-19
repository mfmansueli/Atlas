//
//  EventArtworkViewerSegments.swift
//  Atlas
//

import SwiftUI

/// "Event Card | Event Details" on the viewer's black: the selected one
/// white with dark text.
struct EventArtworkViewerSegments: View {
    @Binding var kind: InAppEventMedia.Kind

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 2) {
            segment(.card, String(localized: "Event Card"))
            segment(.details, String(localized: "Event Details"))
        }
        .padding(2)
        .background(.white.opacity(0.12), in: Capsule())
        .overlay {
            if contrast == .increased { Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Image"))
        .accessibilityIdentifier("events.art.viewer.kind")
    }

    private func segment(_ value: InAppEventMedia.Kind, _ title: String) -> some View {
        let isOn = kind == value
        return Button {
            kind = value
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isOn ? EventArtworkViewerStyle.selectedText : .white)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(isOn ? EventArtworkViewerStyle.selected : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("events.art.viewer.kind.\(value.mcpValue)")
    }
}
