//
//  InAppEventSettingsCard.swift
//  Atlas
//

import SwiftUI

/// The event's settings as App Store Connect has them: badge, dates and
/// where it shows. Its deep link, purpose, priority and primary language,
/// and a draft's dates, are edited in `InAppEventDetailsCard`. A date that
/// has passed before approval shows as a problem, with Fix… on the dates.
struct InAppEventSettingsCard: View {
    let rows: [InAppEventSettingsRow]
    /// Fix…: the Details card, on that date.
    var onFix: (InAppEventDateField) -> Void = { _ in }

    var body: some View {
        Card {
            Text("Event")
                .font(.body.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xSmall) {
                ForEach(rows) { row in
                    GridRow {
                        Text(row.title)
                            .foregroundStyle(Palette.label2)
                            .frame(width: 150, alignment: .leading)
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                            if row.isProblem {
                                Label(row.value, systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(Palette.err)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("events.settings.\(row.key).problem")
                            } else {
                                Text(row.value)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("events.settings.\(row.key)")
                            }
                            if let field = row.fixField {
                                Button("Fix…") { onFix(field) }
                                    .controlSize(.regular)
                                    .accessibilityIdentifier("events.settings.\(row.key).fix")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .font(.callout)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.settings")
    }
}
