//
//  SidebarUtilityIconButton.swift
//  Atlas
//

import SwiftUI

/// Settings, Show the Tour or Atlas Help folded to its tile, side by side
/// with the others when the window is too short for their rows. Its name
/// and shortcut show on hover.
struct SidebarUtilityIconButton: View {
    let title: String
    let systemImage: String
    /// "⌘,"; nil shows none.
    var shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.label)
                .frame(width: 22, height: 22)
                .background(Palette.fill3, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(isHovered ? Palette.fill1 : .clear, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(shortcut.map { "\(title)  \($0)" } ?? title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: 2) {
        SidebarUtilityIconButton(title: "Settings", systemImage: "gearshape", shortcut: "⌘,") {}
        SidebarUtilityIconButton(title: "Show the Tour", systemImage: "questionmark") {}
        SidebarUtilityIconButton(title: "Atlas Help", systemImage: "book", shortcut: "⌘?") {}
    }
    .frame(width: 240)
    .padding()
}
