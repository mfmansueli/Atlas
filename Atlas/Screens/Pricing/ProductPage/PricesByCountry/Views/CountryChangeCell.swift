//
//  CountryChangeCell.swift
//  Atlas
//

import SwiftUI

/// The Change cell (board 73): the open suggestion in the assistant's
/// colour ("→ R$ 129,90" with its change pill) and Accept and Dismiss for
/// this country; a waiting change's "was R$ 249,90", its pill and Undo; or
/// a dash when nothing changes.
struct CountryChangeCell: View {
    let row: CountryPriceRow
    let onOpen: () -> Void
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            if let suggestion = row.suggestion, let change = row.suggestionChange {
                Button(action: onOpen) {
                    Text("\(Image(systemName: "arrow.right")) \(row.currency.format(suggestion.customerPrice))", comment: "kind:label")
                        .atlasTextStyle(.headline)
                        .foregroundStyle(Palette.ai)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help(Text("Why this price", comment: "kind:tooltip"))
                .accessibilityLabel(Text("Suggested \(row.currency.format(suggestion.customerPrice)) in \(row.territory.name)", comment: "kind:accessibility-label"))
                .accessibilityIdentifier("countries.suggestion.\(row.id)")
                PriceChangePill(change: change)
                Spacer(minLength: Spacing.xxSmall)
                Button(String(localized: "Accept", comment: "kind:button"), systemImage: "checkmark", action: onAccept)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.accent)
                    .help(Text("Accept", comment: "kind:help"))
                    .accessibilityLabel(Text("Accept \(row.currency.format(suggestion.customerPrice)) in \(row.territory.name)", comment: "kind:label"))
                    .accessibilityIdentifier("countries.accept.\(row.id)")
                Button(String(localized: "Dismiss", comment: "kind:button"), systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.label2)
                    .help(Text("Dismiss", comment: "kind:help"))
                    .accessibilityLabel(Text("Dismiss the suggestion for \(row.territory.name)", comment: "kind:label"))
                    .accessibilityIdentifier("countries.dismiss.\(row.id)")
            } else if let was = row.wasText {
                Text(was)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .lineLimit(1)
                if let change = row.pendingChange {
                    PriceChangePill(change: change)
                }
                Spacer(minLength: Spacing.xxSmall)
                Button(String(localized: "Undo", comment: "kind:button"), action: onUndo)
                    .plainButton()
                    .accessibilityLabel(Text("Undo the change in \(row.territory.name)", comment: "kind:label"))
                    .accessibilityIdentifier("countries.undo.\(row.id)")
            } else {
                Text(verbatim: "—")
                    .foregroundStyle(Palette.label3)
                    .accessibilityLabel(Text("No change", comment: "kind:label"))
            }
        }
    }
}
