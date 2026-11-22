//
//  AnalyticsStat.swift
//  Atlas
//

import SwiftUI

/// One number on a card: what it is, the number, and a line under it.
struct AnalyticsStat: View {
    let label: String
    let value: String
    var note: String = ""
    var valueColor: Color = Palette.label
    var identifier: String?

    var body: some View {
        Card(padding: Spacing.medium) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(valueColor)
            Text(note).font(.caption).foregroundStyle(Palette.label2).monospacedDigit().lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }
}
