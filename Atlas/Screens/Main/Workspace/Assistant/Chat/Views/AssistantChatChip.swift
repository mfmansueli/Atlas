//
//  AssistantChatChip.swift
//  Atlas
//

import SwiftUI

/// One piece of the question's context under the panel's title: the app,
/// the section, and the version, which can be taken out.
struct AssistantChatChip: View {
    let chip: AssistantChatContext.Chip
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Text(chip.label)
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label)
                .lineLimit(1)
            if chip.isRemovable {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundStyle(Palette.label2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(chip.label)", comment: "kind:accessibility · a chat context chip"))
                .accessibilityIdentifier("chat.chip.remove.\(chip.id)")
            }
        }
        .padding(.leading, Spacing.small)
        .padding(.trailing, chip.isRemovable ? Spacing.xxSmall : Spacing.small)
        .padding(.vertical, Spacing.tiny)
        .background(Palette.fill1, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.chip.\(chip.id)")
    }
}

#Preview {
    HStack {
        AssistantChatChip(chip: .init(id: "app", label: "Lumen", isRemovable: false)) {}
        AssistantChatChip(chip: .init(id: "version", label: "Version 1.4", isRemovable: true)) {}
    }
    .padding()
}
