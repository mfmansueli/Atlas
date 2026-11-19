//
//  EventArtworkViewerToggle.swift
//  Atlas
//

import SwiftUI

/// "App Store Text" and "Text Area" in the viewer's top bar: a pill with
/// a dot, a ring when off and green when on, brighter when on.
struct EventArtworkViewerToggle: View {
    let title: String
    @Binding var isOn: Bool
    let help: String
    let identifier: String
    var isNarrow = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? EventArtworkViewerStyle.inUse : .clear)
                    .overlay { if !isOn { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1) } }
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: isNarrow ? 11.5 : 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isNarrow ? 9 : 12)
            .frame(height: 28)
            .background(.white.opacity(isOn ? 0.24 : 0.12), in: Capsule())
            .overlay {
                if contrast == .increased { Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier(identifier)
    }
}
