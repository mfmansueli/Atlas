//
//  SidebarUtilityRow.swift
//  Atlas
//

import SwiftUI

/// A row under the sections (board 63): Settings, with ⌘, at its right,
/// and Show the Tour. A gray tile with the glyph, the title, and the
/// shortcut when it has one.
struct SidebarUtilityRow: View {
    let title: String
    let systemImage: String
    /// "⌘,"; nil shows none.
    var shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.label)
                    .frame(width: 22, height: 22)
                    .background(Palette.fill3, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut {
                    Text(shortcut)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .padding(.trailing, Spacing.xxSmall)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 5)
            .padding(.trailing, Spacing.xSmall)
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
    VStack(spacing: 2) {
        SidebarUtilityRow(title: "Settings", systemImage: "gearshape", shortcut: "⌘,") {}
        SidebarUtilityRow(title: "Show the Tour", systemImage: "questionmark") {}
    }
    .frame(width: 240)
    .padding()
}
