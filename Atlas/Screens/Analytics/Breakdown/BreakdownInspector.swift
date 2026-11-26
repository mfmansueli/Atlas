//
//  BreakdownInspector.swift
//  Atlas
//

import SwiftUI

/// The selected row in detail: the counts behind its rates, what its page
/// and price look like, and where to fix each.
struct BreakdownInspector: View {
    let row: BreakdownRow
    let table: BreakdownTable
    let context: AnalyticsContext
    /// nil fills the width, when it stands in for the table.
    var width: CGFloat? = Metrics.inspectorWidth
    /// The numbers behind the row's 90-day line; nil draws none.
    var dataset: AnalyticsDataset?
    let onClose: () -> Void
    let onAct: (FindingAction, String) -> Void

    @State private var trend: BreakdownRowTrend?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(spacing: Spacing.small) {
                    if let region = row.regionCode { FlagTile(regionCode: region, size: 16) }
                    Text(row.name).font(.body.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 0)
                    Button(action: onClose) {
                        Image(systemName: "xmark").contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.label2)
                    .help(Text("Close", comment: "kind:tooltip · Break It Down's inspector"))
                    .accessibilityLabel(Text("Close inspector"))
                    .accessibilityIdentifier("analytics.breakdown.inspector.close")
                }
                Text(table.period.text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                group {
                    number(String(localized: "Impressions"), row.totals.impressions.map(AnalyticsText.count))
                    number(String(localized: "Page views"), row.totals.pageViews.map(AnalyticsText.count), note: row.viewRate.text)
                    number(String(localized: "Downloads"), row.totals.downloads.map(AnalyticsText.count), note: row.downloadRate.text)
                    if table.dimension.hasSales {
                        number(String(localized: "Subscription starts"), row.totals.starts.map(AnalyticsText.count), note: row.startRate.text)
                        number(String(localized: "Proceeds"), row.totals.proceeds.map(AnalyticsText.dollars))
                    }
                }
                if let trend {
                    group { BreakdownTrendChart(trend: trend) }
                }
                if !facts.isEmpty {
                    group {
                        ForEach(facts, id: \.label) { fact in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(fact.label).font(.subheadline).foregroundStyle(Palette.label2)
                                Text(fact.value)
                                    .font(.callout)
                                    .foregroundStyle(fact.isWarning ? Palette.warn : Palette.label)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        if index == 0 {
                            Button(action.title) { onAct(action, origin) }.buttonStyle(.borderedProminent)
                        } else {
                            Button(action.title) { onAct(action, origin) }
                        }
                    }
                }
                .controlSize(.regular)
            }
            .padding(Spacing.medium)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5).allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(row.name))
        .accessibilityIdentifier("analytics.breakdown.inspector")
        .task(id: TrendKey(row: row.id, dimension: table.dimension, through: dataset?.through)) {
            trend = dataset.flatMap { dataset in
                BreakdownRowTrend.filter(for: row, dimension: table.dimension, context: context).flatMap {
                    BreakdownRowTrend.make(dataset, filter: $0)
                }
            }
        }
    }

    /// What the line is drawn for: made again only when one changes.
    private struct TrendKey: Hashable {
        var row: String
        var dimension: BreakdownDimension
        var through: AnalyticsDay?
    }

    private struct Fact {
        var label: String
        var value: String
        var isWarning = false
    }

    /// The territory behind the row, when it is one.
    private var territory: String? { table.dimension == .territory ? row.id : nil }
    private var localeCode: String? {
        switch table.dimension {
        case .territory: context.locale(for: row.id)?.code
        case .language: row.id == "other" ? nil : row.id
        default: nil
        }
    }

    private var facts: [Fact] {
        var facts: [Fact] = []
        if let territory {
            if let locale = context.locale(for: territory) {
                facts.append(Fact(label: String(localized: "Sees the page in"), value: locale.name))
            }
            if let state = context.textState(for: territory) {
                facts.append(Fact(label: String(localized: "Page text"), value: state.title, isWarning: state != .written))
            }
            if let own = context.hasOwnScreenshots(for: territory) {
                let value = own ? String(localized: "Its own") : String(localized: "Another language’s")
                facts.append(Fact(label: String(localized: "Screenshots"), value: value, isWarning: !own))
            }
            if let price = context.prices[territory] {
                let ratio = price.ratio.formatted(.number.precision(.fractionLength(1)))
                facts.append(Fact(
                    label: String(localized: "\(price.productName) price"),
                    value: String(localized: "\(price.priceText) · \(ratio)× the purchasing-power price (\(price.suggestedText))"),
                    isWarning: price.ratio >= FindingRules.priceRatio
                ))
            }
        } else if let localeCode, context.machineTranslated.contains(localeCode) {
            facts.append(Fact(label: String(localized: "Page text"), value: PageTextState.machineTranslated.title, isWarning: true))
        }
        facts += BreakdownInspectorFacts.extra(for: row, dimension: table.dimension, context: context).map {
            Fact(label: $0.label, value: $0.value, isWarning: $0.isWarning)
        }
        return facts
    }

    private var actions: [FindingAction] {
        switch table.dimension {
        case .territory:
            var actions: [FindingAction] = [.storePage(locale: localeCode), .screenshots(locale: localeCode)]
            if table.totals.starts != nil { actions.append(.pricing(territory: row.id)) }
            return actions
        case .language: return [.storePage(locale: localeCode), .screenshots(locale: localeCode)]
        case .source:
            // Browse shows the icon, name and subtitle more than the
            // screenshots; search leads with the first three screenshots.
            return row.id == BreakdownInspectorFacts.search
                ? [.screenshots(locale: nil), .storePage(locale: nil)]
                : [.storePage(locale: nil), .screenshots(locale: nil)]
        case .device:
            guard let type = ScreenshotCoverage.displayType(forReportDevice: row.id), let primary = context.primaryLocale?.code else {
                return [.screenshots(locale: nil), .storePage(locale: nil)]
            }
            return [.screenshotsOnDevice(type, locale: primary), .storePage(locale: nil)]
        case .productPage, .referrer, .campaign: return [.screenshots(locale: nil), .storePage(locale: nil)]
        }
    }

    /// What the destination's "From Analytics" bar says.
    private var origin: String {
        String(localized: "\(row.name): downloads per page view \(row.downloadRate.text), page views per impression \(row.viewRate.text).")
    }

    private func group(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) { content() }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    private func number(_ label: String, _ value: String?, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(Palette.label2)
            Spacer(minLength: Spacing.small)
            if let note, note != "—" {
                Text(note).font(.subheadline).foregroundStyle(Palette.label2).monospacedDigit()
            }
            Text(value ?? "—").font(.callout.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
