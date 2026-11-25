//
//  PricesByCountryBulkBar.swift
//  Atlas
//

import SwiftUI

/// With countries selected: "3 selected" · Accept 3 Suggested · Set 2 to
/// Automatic · Deselect. An action shows only when it applies to some of
/// them.
struct PricesByCountryBulkBar: View {
    let selectedCount: Int
    let suggestedCount: Int
    let automaticCount: Int
    let isFree: Bool
    let onAccept: () -> Void
    let onAutomatic: () -> Void
    let onDeselect: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("\(selectedCount) selected", comment: "kind:label")
                .atlasTextStyle(.headline)
                .monospacedDigit()
                .accessibilityIdentifier("countries.bulk.count")
            Spacer(minLength: Spacing.small)
            if suggestedCount > 0 {
                Button(action: onAccept) {
                    HStack(spacing: Spacing.xxSmall) {
                        Text("Accept \(suggestedCount) Suggested", comment: "kind:button")
                        if isFree, suggestedCount > 1 { ProChip() }
                    }
                }
                .rowActionButton()
                .accessibilityIdentifier("countries.bulk.accept")
            }
            if automaticCount > 0 {
                Button(String(localized: "Set \(automaticCount) to Automatic", comment: "kind:button"), action: onAutomatic)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityIdentifier("countries.bulk.automatic")
            }
            Button(String(localized: "Deselect", comment: "kind:button"), action: onDeselect)
                .plainButton()
                .accessibilityIdentifier("countries.bulk.deselect")
        }
        .lineLimit(1)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.raised)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Selected countries", comment: "kind:label"))
        .accessibilityIdentifier("countries.bulk")
    }
}
