//
//  InAppEventResultsCard.swift
//  Atlas
//

import SwiftUI

/// How an ended event did: event page views, opens and downloads from the
/// event, from Apple's numbers; or where to find them when Atlas
/// doesn't have them.
struct InAppEventResultsCard: View {
    let results: InAppEventResults?
    let analyticsURL: URL

    var body: some View {
        Card {
            Text("How it did")
                .font(.body.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let results {
                HStack(alignment: .top, spacing: Spacing.medium) {
                    number(results.pageViews, String(localized: "Event page views"))
                    number(results.opens, String(localized: "Opens from the event"))
                    number(results.downloads, String(localized: "Downloads from the event"))
                }
                Text(results.note)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            } else {
                Text("Apple counts an event’s page views, opens and downloads in App Store Connect’s App Analytics. Atlas doesn’t read them yet.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                ExternalLinkButton(title: String(localized: "Open App Analytics"), url: analyticsURL, isLink: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.results")
    }

    private func number(_ value: Int, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
