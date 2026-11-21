//
//  ProductPageLanguageChip.swift
//  Atlas
//

import SwiftUI

/// One language of the page: its flag and name, a purple dot while a text
/// is suggested, a tick when it has content of its own.
struct ProductPageLanguageChip: View {
    let language: ProductPageLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                FlagTile(regionCode: ProductPageChangeBuilder.region(language.code) ?? "", size: 12)
                    .frame(width: 20)
                Text(shortName)
                    .font(.caption)
                    .lineLimit(1)
                switch language.state {
                case .suggested:
                    Circle()
                        .fill(isSelected ? Color.white : Palette.suggestionBadge)
                        .frame(width: 7, height: 7)
                case .own:
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Palette.label2)
                case .same:
                    EmptyView()
                }
            }
            .padding(.leading, 3)
            .padding(.trailing, 9)
            .frame(height: 26)
            .foregroundStyle(isSelected ? Color.white : Palette.label)
            .background(isSelected ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.fill1), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Palette.separator, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // The button stays the element, so VoiceOver can press it.
        .accessibilityLabel(Text(language.spokenLabel))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var shortName: String {
        StoreLocaleCatalog.locale(code: language.code)?.shortName ?? language.name
    }
}
