//
//  ChangeResultView.swift
//  Atlas
//

import SwiftUI

/// One change's result, laid out like Pricing → Results: before → after
/// with its verdict, the counts behind it, and the difference.
struct ChangeResultView: View {
    let change: MeasuredChange
    let result: ChangeResult?
    let onOpenPricing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.title).font(.title3.weight(.semibold))
                Text("Pushed \(AnalyticsText.day(change.date)) · \(change.kind.area.title) · measured on: \(change.stageTitle)")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            if change.kind == .prices {
                Card {
                    Text("Price changes have their own results").font(.headline)
                    Text("Pricing → Results measures a price change per territory: starts and proceeds, 28 days before against 28 days after.")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                    Button("Open Pricing", action: onOpenPricing)
                }
            } else if let result {
                content(result)
            } else {
                Text("Apple’s reports don’t cover the days around this change, or the step it’s measured on isn’t available.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.changes.result")
    }

    @ViewBuilder
    private func content(_ result: ChangeResult) -> some View {
        Text("\(result.before.text) against \(result.after.text)")
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .monospacedDigit()
        AdaptiveGridLayout(minimumWidth: 200, spacing: Spacing.medium) {
            Card(padding: Spacing.medium) {
                title(result.main.title)
                Text(result.beforeAfterText).font(.title3.weight(.semibold)).monospacedDigit()
                Pill(text: result.main.comparison.outcome.verdict, style: result.main.comparison.outcome.isLower ? .warning : .neutral)
            }
            Card(padding: Spacing.medium) {
                title(String(localized: "Counts behind it"))
                Text("Before: \(counts(result.main.before))").font(.callout).monospacedDigit()
                Text("After: \(counts(result.main.after))").font(.callout).monospacedDigit()
            }
            Card(padding: Spacing.medium) {
                title(String(localized: "Difference"))
                Text(result.main.comparison.pointsText.isEmpty ? "—" : result.main.comparison.pointsText).font(.callout).monospacedDigit()
                Text("90% confidence. “About the same” means the difference could be chance.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        switch result.state {
        case let .measuring(day, ends):
            Card(padding: Spacing.medium) {
                MeterBar(fraction: Double(day) / Double(ResultsEvaluator.windowDays), tint: Palette.accent)
                Text("Day \(day) of \(ResultsEvaluator.windowDays) · final on \(AnalyticsText.day(ends))").font(.caption).monospacedDigit().foregroundStyle(Palette.label2)
                Text("An early read. The result is final on \(AnalyticsText.day(ends)), after 28 days; early numbers often move.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
        case .noBefore:
            note(String(localized: "Apple’s reports don’t reach back to the 28 days before this change, so there’s nothing to compare with."))
        case .final:
            if result.isTooFew {
                note(String(localized: "Too few to tell a real change from chance: \(counts(result.main.before)) before, \(counts(result.main.after)) after."))
            }
        }
        if let old = change.oldValue, let new = change.newValue {
            Card(padding: Spacing.medium) {
                title(String(localized: "What changed"))
                Text("\(old.isEmpty ? "—" : old) → \(new)").font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
        if !result.others.isEmpty {
            VStack(spacing: 0) {
                row(
                    String(localized: "Other steps, to check it didn’t hurt them"), String(localized: "Before → after"),
                    String(localized: "Verdict"), isHeader: true
                )
                ForEach(result.others, id: \.title) { side in
                    Divider()
                    row(side.title, "\(side.before.text) → \(side.after.text)", side.comparison.outcome.verdict, isHeader: false)
                }
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        }
        Text("""
        Seasonality, featuring and your own marketing also move these numbers. This is the same before-and-after as Pricing → \
        Results, which measures price changes per territory; here every other kind of change is measured on the step it should move.
        """)
        .font(.subheadline)
        .foregroundStyle(Palette.label2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func counts(_ rate: AnalyticsRate) -> String {
        switch rate {
        case .missing: "—"
        case let .tooFew(count, total): String(localized: "\(AnalyticsText.count(count)) of \(AnalyticsText.count(total))")
        case let .measured(rate): String(localized: "\(AnalyticsText.count(rate.count)) of \(AnalyticsText.count(rate.total))")
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
    }

    private func row(_ first: String, _ second: String, _ third: String, isHeader: Bool) -> some View {
        HStack {
            Text(first).frame(maxWidth: .infinity, alignment: .leading)
            Text(second).monospacedDigit().frame(width: 150, alignment: .leading)
            Text(third).frame(width: 150, alignment: .leading)
        }
        .font(isHeader ? .caption.weight(.semibold) : .callout)
        .foregroundStyle(isHeader ? Palette.label2 : Palette.label)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}
