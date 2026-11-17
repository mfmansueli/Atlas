//
//  SubmitWhatsNewRow.swift
//  Atlas
//

import SwiftUI

/// One language's What's New in the Submit sheet: its text and whether
/// it's written, accepted, suggested or missing. A suggested one shows the
/// suggestion with Accept; a missing one opens the Store Page.
struct SubmitWhatsNewRow: View {
    let row: WhatsNewRow
    let onAccept: (FieldSuggestion) -> Void
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                FlagTile(regionCode: row.locale.regionCode)
                    .frame(width: 20)
                Text(row.locale.name)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
                Text(row.text.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if row.state == .missing {
                    Button("Write It…", action: onWrite)
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .accessibilityIdentifier("submit.whatsNew.write.\(row.locale.code)")
                }
                Pill(text: row.statusTitle, style: pillStyle)
                    .fixedSize()
            }
            .frame(minHeight: 30)
            if case let .suggested(suggestion) = row.state {
                suggestionBox(suggestion)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("submit.whatsNew.\(row.locale.code)")
    }

    private var pillStyle: PillStyle {
        switch row.state {
        case .written, .notPushed: .outline
        case .suggested: .machineTranslated
        case .missing: .warning
        }
    }

    private func suggestionBox(_ suggestion: FieldSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Text("SUGGESTED · \(row.locale.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.machineTranslated)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: suggestion.source)
            }
            Text(suggestion.value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, row.locale.isRTL ? .rightToLeft : .leftToRight)
            Button("Accept") { onAccept(suggestion) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("submit.whatsNew.accept.\(row.locale.code)")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.machineTranslatedTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.machineTranslatedMark.opacity(0.35), lineWidth: 1))
    }
}
