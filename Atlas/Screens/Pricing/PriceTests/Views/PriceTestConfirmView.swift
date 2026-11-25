//
//  PriceTestConfirmView.swift
//  Atlas
//

import SwiftUI

/// The test's one level-3 confirmation (board 76, `pt-confirm`): What,
/// When, Who, Compared with and To undo, then Add to Review & Push. Both
/// price changes wait as one item; nothing changes until the push.
struct PriceTestConfirmView: View {
    let plan: PriceTestPlan
    let today: Date
    let onBack: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Start the \(plan.region.title) Price Test?", comment: "kind:sheet-title")
                    .atlasTextStyle(.title2)
                Text("Both price changes go in one push. Nothing changes on the App Store until you push.", comment: "kind:sheet-body")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                PriceTestFactRow(label: String(localized: "What", comment: "kind:label"), value: what)
                PriceTestFactRow(label: String(localized: "When", comment: "kind:label"), value: when)
                PriceTestFactRow(label: String(localized: "Who", comment: "kind:label"), value: who)
                PriceTestFactRow(label: String(localized: "Compared with", comment: "kind:label"), value: comparedWith)
                PriceTestFactRow(
                    label: String(localized: "To undo", comment: "kind:label"),
                    value: String(localized: "End the test any time in Results. The old prices come back when you push.", comment: "kind:sheet-body")
                )
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button(String(localized: "Back", comment: "kind:button"), action: onBack)
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("priceTest.confirm.back")
                Button(String(localized: "Add to Review & Push", comment: "kind:button"), action: onAdd)
                    .primaryButton(isDefault: true)
                    .accessibilityIdentifier("priceTest.confirm.add")
            }
        }
        .padding(Spacing.xxLarge)
        .frame(width: Metrics.priceTestSheetWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.confirm")
    }

    /// "Lumen Plus Annual, 20% lower in 14 countries in Europe. Germany
    /// €39.99 → €31.99, …"
    private var what: String {
        let line = String(
            localized: "\(plan.productName), \(plan.step.phrase) in \(plan.countries.count) countries in \(plan.region.title).",
            comment: "kind:sheet-body"
        )
        return line + " " + PriceTestText.examples(plan.examples) + "."
    }

    /// "From when you push (about Nov 25) to Dec 23, 2026. Then the old
    /// prices come back on their own."
    private var when: String {
        let ends = Calendar.gmtGregorian.date(byAdding: .day, value: PriceTest.days, to: today) ?? today
        return String(
            localized: """
            From when you push (about \(PriceTestText.shortDate(today))) to \(PricingText.date(ends)). \
            Then the old prices come back on their own.
            """,
            comment: "kind:sheet-body"
        )
    }

    private var who: String {
        let region = plan.region.title
        if !plan.hasDecreases {
            return String(localized: "New subscribers in \(region) only. Existing subscribers keep their price.", comment: "kind:sheet-body")
        }
        return plan.keepsTestPrice
            ? String(
                localized: "New subscribers in \(region), and those who renew during the test. They keep the test price afterward.",
                comment: "kind:sheet-body"
            )
            : String(
                localized: "New subscribers in \(region), and those who renew during the test. Apple asks them to accept the old price back.",
                comment: "kind:sheet-body"
            )
    }

    private var comparedWith: String {
        guard let control = plan.control else {
            return String(localized: "No comparison: before against during only. Less sure.", comment: "kind:sheet-body")
        }
        return String(localized: "\(control.title), same 28 days, price unchanged.", comment: "kind:sheet-body")
    }
}
