//
//  SubmitWhatsNewRow.swift
//  Atlas
//

import SwiftUI

/// One language's What's New in the Submit sheet: its text and whether
/// it's written, accepted, suggested or missing. A suggested one shows the
/// suggestion with Accept, which settles it (effect 5); a missing one opens
/// the Store Page.
struct SubmitWhatsNewRow: View {
    let row: WhatsNewRow
    let onAccept: (FieldSuggestion) -> Void
    let onWrite: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

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
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if row.state == .missing {
                    Button("Write It…", action: onWrite)
                        .buttonStyle(.link)
                        .controlSize(.regular)
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
                Text("Suggested · \(row.locale.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SuggestionSourceTag(source: suggestion.source)
            }
            SuggestedText(suggestion.value, arrivalKey: suggestion.id, arrivedAt: suggestion.arrivedAt)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, row.locale.isRTL ? .rightToLeft : .leftToRight)
            Button("Accept") { accept(suggestion) }
                .rowActionButton()
                .controlSize(.regular)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("submit.whatsNew.accept.\(row.locale.code)")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .suggestionSurface(isSettling: isSettling, arrivalKey: suggestion.id, arrivedAt: suggestion.arrivedAt)
    }

    private func accept(_ suggestion: FieldSuggestion) {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept(suggestion)
        }
    }
}
