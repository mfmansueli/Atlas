//
//  InAppEventLanguageChip.swift
//  Atlas
//

import SwiftUI

/// One language of an event in the language bar: its flag and name, a
/// purple dot while a suggestion or a revision waits, a blue one for text
/// not pushed.
struct InAppEventLanguageChip: View {
    let language: InAppEventLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                FlagTile(regionCode: language.locale?.regionCode ?? "", size: 12)
                    .frame(width: 20)
                Text(language.shortName)
                    .font(.caption)
                    .lineLimit(1)
                switch language.state {
                case .suggested, .revision:
                    Circle()
                        .fill(isSelected ? Color.white : Palette.suggestionBadge)
                        .frame(width: 7, height: 7)
                case .notPushed:
                    UnsavedDot(size: 6)
                case .missing:
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Palette.label3)
                case .written:
                    EmptyView()
                }
            }
            .padding(.leading, 3)
            .padding(.trailing, 9)
            .frame(height: 24)
            .foregroundStyle(isSelected ? Color.white : Palette.label)
            .background(isSelected ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.fill1), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Palette.separator, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(language.accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
