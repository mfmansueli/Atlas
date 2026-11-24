//
//  MenuBarItemButton.swift
//  Atlas
//

import SwiftUI

/// One clickable line of the menu bar's menu, drawn as a menu item: the
/// symbol column (README-DS §13: secondary label, an empty slot when the
/// line has no standard symbol, so the names line up), the accent colour
/// under the pointer, a second line when there's one, then a count and the
/// key equivalent on the right.
struct MenuBarItemButton: View {
    let title: String
    var systemImage: String?
    var detail: String?
    var count: Int?
    var shortcut: String?
    var identifier: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                // The empty slot keeps a symbol's baseline and width.
                Image(systemName: systemImage ?? "circle")
                    .opacity(systemImage == nil ? 0 : 1)
                    .foregroundStyle(isHovered ? Color.white : Palette.label2)
                    .frame(width: Metrics.symbolColumn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isHovered ? Color.white : Palette.label)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Palette.label2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let count, count > 0 {
                    Text(count, format: .number)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(isHovered ? Color.white.opacity(0.3) : Palette.fill3, in: Capsule())
                        .foregroundStyle(isHovered ? Color.white : Palette.label)
                }
                if let shortcut {
                    Text(shortcut)
                        .font(.callout)
                        .foregroundStyle(isHovered ? Color.white.opacity(0.8) : Palette.label3)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minHeight: 28)
            .background(isHovered ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }
}

#Preview {
    VStack(spacing: 1) {
        MenuBarItemButton(title: "Open Atlas", systemImage: "arrow.up.forward.app", shortcut: "⌘O") {}
        MenuBarItemButton(title: "Review & Push…", systemImage: "arrow.up.circle", count: 4) {}
        MenuBarItemButton(title: "6 reviews need a reply", systemImage: "star.bubble", detail: "Replies are suggested in each language") {}
    }
    .padding(6)
    .frame(width: 330)
}
