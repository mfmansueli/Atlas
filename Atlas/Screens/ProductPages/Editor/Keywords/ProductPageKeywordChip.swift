//
//  ProductPageKeywordChip.swift
//  Atlas
//

import SwiftUI

/// One of the approved version's keywords: chosen for this page (ticked),
/// on another page (with its name), or free.
struct ProductPageKeywordChip: View {
    let keyword: String
    let isChosen: Bool
    /// The other page it leads to.
    let owner: String?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxSmall) {
                if isChosen {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                }
                Text(keyword)
                    .font(.callout)
                if let owner {
                    Text("· \(owner)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .foregroundStyle(isChosen ? Palette.accentText : Palette.label)
            .background(isChosen ? AnyShapeStyle(Palette.accentTint) : AnyShapeStyle(owner == nil ? Color.clear : Palette.fill1), in: Capsule())
            .overlay(Capsule().strokeBorder(isChosen ? Palette.accent.opacity(0.6) : Palette.separator2, lineWidth: isChosen ? 1 : 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityLabel(Text(spokenLabel))
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }

    private var spokenLabel: String {
        if isChosen { return String(localized: "\(keyword), chosen") }
        if let owner { return String(localized: "\(keyword), on “\(owner)”") }
        return keyword
    }
}
