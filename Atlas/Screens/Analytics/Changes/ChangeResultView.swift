//
//  ChangeResultView.swift
//  Atlas
//

import SwiftUI

/// One change's result (board 92), laid out like Pricing → Results: the
/// step before → after with its verdict, the counts behind it and the
/// difference (in one column at 860 pt), the step day by day, and what the
/// state means: an early read while the 28 days run, too few to tell, or,
/// for prices, the way to Pricing → Results.
struct ChangeResultView: View {
    let change: MeasuredChange
    let result: ChangeResult?
    /// What the chart is drawn from; nil draws none.
    var dataset: AnalyticsDataset?
    var context = AnalyticsContext.empty
    let onOpenPricing: () -> Void

    @State private var width: CGFloat = 0
    @State private var chart: ChangeChart?

    private var status: ChangeStatus { ChangeStatus.make(change, result: result) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(change.title).atlasTextStyle(.title2)
                Text("Pushed \(AnalyticsText.day(change.date)) · \(change.kind.area.title) · measured on: \(change.stageTitle)", comment: "kind:description · After Changes")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
            }
            if status == .pricing {
                pricing
            } else if let result {
                content(result)
            } else {
                Text("Apple’s reports miss this change’s dates or measured step.", comment: "kind:empty-state · After Changes")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.changes.result")
        .task(id: ChartKey(change: change.id, through: dataset?.through, hasResult: result != nil)) {
            chart = result.flatMap { result in dataset.flatMap { ChangeChart.make(result, dataset: $0, context: context) } }
        }
    }

    /// What the chart is made again for.
    private struct ChartKey: Hashable {
        var change: MeasuredChange.ID
        var through: AnalyticsDay?
        var hasResult: Bool
    }

    private var pricing: some View {
        Card {
            Text("Price changes have their own results", comment: "kind:section-title · After Changes").atlasTextStyle(.headline)
            Text(
                "Prices changed on \(AnalyticsText.day(change.date)). Price results live in Pricing → Results, where each territory is compared 28 days before and after.",
                comment: "kind:description · After Changes, a price change"
            )
            .atlasTextStyle(.callout)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "Open Pricing", comment: "kind:button · After Changes"), action: onOpenPricing)
                .controlSize(.regular)
                .accessibilityIdentifier("analytics.changes.openPricing")
        }
        .accessibilityIdentifier("analytics.changes.pricing")
    }

    @ViewBuilder
    private func content(_ result: ChangeResult) -> some View {
        Text("\(result.before.text) against \(result.after.text)", comment: "kind:description · After Changes")
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .monospacedDigit()
        results(result)
        if let chart { ChangeChartView(chart: chart) }
        switch result.state {
        case let .measuring(day, ends):
            Card(padding: Spacing.medium) {
                MeterBar(fraction: Double(day) / Double(ResultsEvaluator.windowDays), tint: Palette.accent)
                Text("Day \(day) of \(ResultsEvaluator.windowDays) · final on \(AnalyticsText.day(ends))", comment: "kind:progress-step · After Changes")
                    .atlasTextStyle(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Palette.label2)
                Text("An early read. The result is final on \(AnalyticsText.day(ends)), after 28 days; early numbers often move.", comment: "kind:hint · After Changes")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("analytics.changes.waiting")
        case .noBefore:
            AnalyticsNotice(
                tone: .info,
                text: String(localized: "Nothing to compare: Apple has no data from the 28 days before.", comment: "kind:banner · After Changes")
            )
        case .final:
            if result.isTooFew {
                AnalyticsNotice(
                    tone: .info,
                    text: String(
                        localized: "Too few to tell from chance: \(counts(result.main.before)) before, \(counts(result.main.after)) after.",
                        comment: "kind:banner · After Changes"
                    ),
                    identifier: "analytics.changes.tooFew"
                )
            }
        }
        if let old = change.oldValue, let new = change.newValue {
            Card(padding: Spacing.medium) {
                title(String(localized: "What changed", comment: "kind:section-title · After Changes"))
                Text("\(old.isEmpty ? "—" : old) → \(new)")
                    .atlasTextStyle(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if !result.others.isEmpty { others(result) }
        Text(
            "Seasons, featuring and marketing move these numbers too. Each change is measured on the step it should move; prices in Pricing → Results.",
            comment: "kind:hint · After Changes"
        )
        .atlasTextStyle(.subheadline)
        .foregroundStyle(Palette.label2)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The three results: side by side, or stacked at 860 pt.
    @ViewBuilder
    private func results(_ result: ChangeResult) -> some View {
        if ChangeResultLayout.stacksResults(width: width) {
            VStack(alignment: .leading, spacing: Spacing.small) { resultCards(result) }
        } else {
            HStack(alignment: .top, spacing: Spacing.medium) { resultCards(result) }
        }
    }

    @ViewBuilder
    private func resultCards(_ result: ChangeResult) -> some View {
        Card(padding: Spacing.medium) {
            title(result.main.title)
            Text(result.beforeAfterText).atlasTextStyle(.title3).monospacedDigit()
            Pill(text: result.main.comparison.outcome.verdict, style: status.pillStyle)
        }
        .accessibilityIdentifier("analytics.changes.verdict")
        Card(padding: Spacing.medium) {
            title(String(localized: "Counts behind it", comment: "kind:section-title · After Changes"))
            Text("Before: \(counts(result.main.before))", comment: "kind:label · After Changes").atlasTextStyle(.callout).monospacedDigit()
            Text("After: \(counts(result.main.after))", comment: "kind:label · After Changes").atlasTextStyle(.callout).monospacedDigit()
        }
        Card(padding: Spacing.medium) {
            title(String(localized: "Difference", comment: "kind:section-title · After Changes"))
            Text(result.main.comparison.pointsText.isEmpty ? "—" : result.main.comparison.pointsText).atlasTextStyle(.callout).monospacedDigit()
            Text("90% confidence. “About the same” means the difference could be chance.", comment: "kind:hint · After Changes")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func others(_ result: ChangeResult) -> some View {
        VStack(spacing: 0) {
            row(
                String(localized: "Other steps, to check it didn’t hurt them", comment: "kind:column · After Changes"),
                String(localized: "Before → after", comment: "kind:column · After Changes"),
                String(localized: "Verdict", comment: "kind:column · After Changes"),
                isHeader: true
            )
            ForEach(result.others, id: \.title) { side in
                Divider()
                row(side.title, "\(side.before.text) → \(side.after.text)", side.comparison.outcome.verdict, isHeader: false)
            }
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
    }

    private func counts(_ rate: AnalyticsRate) -> String {
        switch rate {
        case .missing: "—"
        case let .tooFew(count, total): String(localized: "\(AnalyticsText.count(count)) of \(AnalyticsText.count(total))")
        case let .measured(rate): String(localized: "\(AnalyticsText.count(rate.count)) of \(AnalyticsText.count(rate.total))")
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).atlasTextStyle(.subheadline).fontWeight(.semibold).foregroundStyle(Palette.label2)
    }

    /// One line of the other steps: it wraps under the step's name rather
    /// than squeezing it at 860 pt.
    private func row(_ first: String, _ second: String, _ third: String, isHeader: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(first).frame(maxWidth: .infinity, alignment: .leading)
                Text(second).monospacedDigit().lineLimit(1)
                Text(third).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(first)
                Text("\(second) · \(third)").monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .atlasTextStyle(isHeader ? .subheadline : .callout)
        .fontWeight(isHeader ? .semibold : .regular)
        .foregroundStyle(isHeader ? Palette.label2 : Palette.label)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}
