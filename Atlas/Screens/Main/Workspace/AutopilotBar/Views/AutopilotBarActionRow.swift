//
//  AutopilotBarActionRow.swift
//  Atlas
//

import SwiftUI

/// One action in the open bar's list (board 80): its symbol, what it does
/// and from what, and PRO on Free. A click sends it like a message.
struct AutopilotBarActionRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var note: String?
    var isPro = false
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.ai)
                    .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(title)
                        .atlasTextStyle(.body)
                        .foregroundStyle(Palette.label)
                        .lineLimit(1)
                    if let line = note ?? subtitle {
                        Text(line)
                            .atlasTextStyle(.callout)
                            .foregroundStyle(Palette.label2)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isPro { ProChip() }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(isHovered ? Palette.fill1 : Color.clear, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text([title, isPro ? String(localized: "Pro", comment: "kind:accessibility") : nil].compactMap(\.self).joined(separator: ", ")))
        .accessibilityHint(Text(subtitle ?? ""))
        .accessibilityIdentifier("autopilotBar.row")
    }
}
