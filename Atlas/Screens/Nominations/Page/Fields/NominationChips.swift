//
//  NominationChips.swift
//  Atlas
//

import SwiftUI

/// Toggle chips that wrap: Devices and Languages.
struct NominationChips: View {
    struct Option: Identifiable, Hashable {
        var id: String
        var title: String
    }

    let options: [Option]
    let selected: Set<String>
    var identifier: String
    let onToggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Spacing.xSmall) {
            ForEach(options) { option in
                let isOn = selected.contains(option.id)
                Button {
                    onToggle(option.id)
                } label: {
                    HStack(spacing: Spacing.xxSmall) {
                        if isOn { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                        Text(option.title)
                    }
                    .font(.subheadline.weight(isOn ? .medium : .regular))
                    .foregroundStyle(isOn ? Palette.accentText : Palette.label)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.xxSmall)
                    .background(isOn ? Palette.accentTint : Palette.fill1, in: Capsule())
                    .overlay(Capsule().strokeBorder(isOn ? Palette.accent : Palette.separator, lineWidth: isOn ? 1 : 0.5))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("\(identifier).\(option.id)")
            }
        }
    }
}
