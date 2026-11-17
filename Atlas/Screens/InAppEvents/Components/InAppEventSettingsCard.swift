//
//  InAppEventSettingsCard.swift
//  Atlas
//

import SwiftUI

/// The event's settings as App Store Connect has them: badge, dates,
/// where it shows, purpose and priority. They're changed there.
struct InAppEventSettingsCard: View {
    let rows: [(title: String, value: String)]

    var body: some View {
        Card {
            Text("Event")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xSmall) {
                ForEach(rows, id: \.title) { row in
                    GridRow {
                        Text(row.title)
                            .foregroundStyle(Palette.label2)
                            .frame(width: 150, alignment: .leading)
                        Text(row.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.callout)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.settings")
    }
}
