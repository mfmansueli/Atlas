//
//  AssistantFolderRow.swift
//  Atlas
//

import SwiftUI

/// A folder in step 1: the one Atlas found (with Use This Folder) or the
/// one accepted (with Change…), in a card like the design's.
struct AssistantFolderRow<Action: View>: View {
    /// "Lumen", or "**Lumen** · found on this Mac".
    let title: Text
    let path: String
    var detail: String?
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "folder.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.accentText)
                .frame(width: 32, height: 32)
                .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.callout)
                Text(ProjectFolderPath.abbreviated(path))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action()
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}
