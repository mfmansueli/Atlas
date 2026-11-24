//
//  AssistantChatShortcutHint.swift
//  Atlas
//

import SwiftUI

/// “⌘J” in a small key cap, in the closed chat and the panel's title.
struct AssistantChatShortcutHint: View {
    var body: some View {
        Text(verbatim: "⌘J")
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .padding(.horizontal, Spacing.xxSmall)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    AssistantChatShortcutHint().padding()
}
