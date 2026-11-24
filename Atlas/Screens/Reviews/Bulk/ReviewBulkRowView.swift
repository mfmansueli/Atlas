//
//  ReviewBulkRowView.swift
//  Atlas
//

import SwiftUI

/// One language of Reply to All: a checkbox, the language, how many
/// reviews get its message, and the message.
struct ReviewBulkRowView: View {
    let row: ReviewBulkRow
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle(isOn: Binding(get: { isOn }, set: { _ in onToggle() })) {
                Text("Reply in \(row.languageName)")
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel(Text("Reply in \(row.languageName)"))
            .accessibilityIdentifier("reviews.bulk.toggle.\(row.languageCode)")
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.small) {
                    if !row.territory.isEmpty {
                        FlagTile(regionCode: row.territory)
                    }
                    Text(row.languageName)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(ReviewText.reviews(row.reviewIDs.count))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.label2)
                }
                Text(row.text)
                    .font(.callout)
                    .foregroundStyle(isOn ? Palette.label : Palette.label3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, ReviewLanguage.isRightToLeft(row.languageCode) ? .rightToLeft : .leftToRight)
                if let gloss = row.gloss { GlossLine(gloss: gloss) }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(isOn ? Palette.aiSurface : Palette.fill1, in: shape)
        .overlay(shape.strokeBorder(isOn ? Palette.aiMark.opacity(0.35) : Palette.separator, lineWidth: isOn ? 1 : 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.bulk.row.\(row.languageCode)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }
}
