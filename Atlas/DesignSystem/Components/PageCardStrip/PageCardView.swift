//
//  PageCardView.swift
//  Atlas
//

import SwiftUI

/// One card of a `PageCardStrip`: symbol, name and status. The open one
/// has the accent's tint and edge.
struct PageCardView<ID: Hashable>: View {
    let item: PageCardItem<ID>
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isSelected ? Palette.accentText : Palette.label2)
                    .frame(width: Metrics.pageCardTile, height: Metrics.pageCardTile)
                    .background(isSelected ? Palette.raised : Palette.fill2, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .atlasTextStyle(.headline)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                    if item.isLoading {
                        SkeletonLine(fraction: 0.6)
                    } else if let status = item.status {
                        Text(status)
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(item.tone.color)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, Spacing.small)
            .padding(.trailing, Spacing.medium)
            .frame(minWidth: Metrics.pageCardMinWidth, minHeight: Metrics.pageCardHeight, alignment: .leading)
            .background(isSelected ? Palette.accentTint : Palette.fill1, in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Palette.accent : Palette.separator2, lineWidth: isSelected || contrast == .increased ? 1 : 0.5)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .help(accessibilityText)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    private var accessibilityText: String {
        guard let status = item.status, !item.isLoading else { return item.title }
        return "\(item.title), \(status)"
    }
}
