//
//  SidebarFooterTile.swift
//  Atlas
//

import SwiftUI

/// What Settings and Help ▾ look like at the bottom of the sidebar (board
/// 71): a 30 pt tile with the glyph and the name, always the name, and a
/// small chevron when it opens a menu. Shares the row with the other and
/// shrinks with the sidebar: no minimum width of its own, the name
/// truncates first.
struct SidebarFooterTile: View {
    let title: String
    let systemImage: String
    /// Help ▾: a menu opens.
    var opensMenu = false
    /// The menu is open.
    var isOn = false

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Palette.label)
                .lineLimit(1)
                .truncationMode(.tail)
            if opensMenu {
                Image(systemName: "chevron.down")
                    .atlasTextStyle(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
            }
        }
        .atlasTextStyle(.body)
        .padding(.horizontal, Spacing.xSmall)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: Metrics.sidebarFooterButtonHeight)
        .background(isHovered || isOn ? Palette.fill2 : Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .contentShape(shape)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    HStack(spacing: Spacing.xSmall) {
        SidebarFooterTile(title: "Settings", systemImage: "gearshape")
        SidebarFooterTile(title: "Help", systemImage: "questionmark.circle", opensMenu: true)
    }
    .frame(width: 220)
    .padding()
}
