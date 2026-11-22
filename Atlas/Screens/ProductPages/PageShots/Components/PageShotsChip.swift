//
//  PageShotsChip.swift
//  Atlas
//

import SwiftUI

/// A language or a device that does or doesn't get the page's own images:
/// a checkbox drawn as a chip, its flag before a language's name. A chip
/// that can't change (the primary language) is shown on and dimmed.
struct PageShotsChip: View {
    let title: String
    var regionCode: String?
    let isOn: Bool
    var isEnabled = true
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let regionCode {
                    FlagTile(regionCode: regionCode, size: 12)
                        .frame(width: 20)
                }
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.leading, regionCode == nil ? 10 : 3)
            .padding(.trailing, 10)
            .frame(height: 26)
            .foregroundStyle(isOn ? Color.white : Palette.label)
            .background(isOn ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.fill1), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.separator, lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // The button stays the element, so VoiceOver can press it: an
        // element of its own (children: .ignore) has no press action.
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? String(localized: "on") : String(localized: "off")))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}
