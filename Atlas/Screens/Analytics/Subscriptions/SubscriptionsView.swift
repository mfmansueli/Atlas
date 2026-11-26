//
//  SubscriptionsView.swift
//  Atlas
//

import SwiftUI

/// Subscriptions: active subscribers, trial → paid, renewals, why people
/// cancel, per subscription and per territory. Kept to what leads to an
/// action in Pricing, the paywall or Retention.
struct SubscriptionsView: View {
    let report: SubscriptionsReport
    let appName: String
    /// Live retention messages; nil when not read.
    let liveRetentionMessages: Int?
    var retention: RetentionReport?
    var lifecycle: LifecycleReport?
    var gracePeriod: GracePeriodSetting?
    /// Apple's subscription rows name product pages: Break It Down can split them.
    var hasPageRows = false
    var onShow: (SubscriptionsPane) -> Void = { _ in }
    var onBreakDown: () -> Void = {}
    let onAct: (FindingAction, String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                notices
                AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
                    card(String(localized: "Active subscribers"), report.active.map(AnalyticsText.count) ?? "—", report.activeChange.map { String(localized: "\($0) vs a period earlier") } ?? "")
                    Card(padding: Spacing.medium) {
                        title(String(localized: "Trial → paid"))
                        RateLabel(rate: report.trialToPaid, font: .title3.weight(.semibold))
                        Text(report.trialToPaidComparison.map { "\($0.pointsText) \($0.outcome.title)" } ?? String(localized: "Of trials that ended in the period"))
                            .font(.subheadline).foregroundStyle(Palette.label2).monospacedDigit()
                    }
                    card(
                        String(localized: "Proceeds, \(report.period.length) days"), AnalyticsText.dollars(report.proceeds),
                        [report.proceedsChange, String(localized: "after Apple’s commission and taxes")].compactMap(\.self).joined(separator: " · ")
                    )
                    card(
                        String(localized: "Refunds"), AnalyticsText.count(report.refunds),
                        report.charges > 0 ? String(localized: "\(AnalyticsText.percent(Double(report.refunds) / Double(report.charges))) of \(AnalyticsText.count(report.charges)) charges") : ""
                    )
                }
                if let retention, !retention.isEmpty {
                    RetentionSummaryBlock(report: retention) { onShow(.retention) }
                } else {
                    SubscriptionsSectionRow(
                        title: String(localized: "Retention", comment: "kind:section-title · Analytics → Subscriptions"),
                        detail: String(localized: "When someone taps Cancel Subscription", comment: "kind:description · Analytics → Subscriptions"),
                        button: String(localized: "See Retention", comment: "kind:button"),
                        identifier: "analytics.subscriptions.seeRetention"
                    ) { onShow(.retention) }
                }
                AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
                    if !showsBillingNotice {
                        SubscriptionsSectionRow(
                            title: String(localized: "Billing", comment: "kind:section-title · Analytics → Subscriptions"),
                            detail: String(localized: "Subscribers Apple couldn’t charge", comment: "kind:description · Analytics → Subscriptions"),
                            button: String(localized: "See Billing and Plans", comment: "kind:button"),
                            identifier: "analytics.subscriptions.seeBilling"
                        ) { onShow(.billing) }
                    }
                    SubscriptionsSectionRow(
                        title: String(localized: "Offers", comment: "kind:section-title · Analytics → Subscriptions"),
                        detail: String(
                            localized: "Introductory, promotional and win-back offers, and how many people take them",
                            comment: "kind:description · Analytics → Subscriptions"
                        ),
                        button: String(localized: "See Offers", comment: "kind:button"),
                        identifier: "analytics.subscriptions.seeOffers"
                    ) { onShow(.offers) }
                }
                AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
                    renewals
                    cancellations
                }
                AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
                    products
                    territories
                }
                Text(
                    "Trial → paid: trials ended in this period. \(Image(systemName: RateStanding.better.systemImage)) \(Image(systemName: RateStanding.worse.systemImage)) \(Image(systemName: RateStanding.same.systemImage)) compare with \(appName)’s overall rate. Pacific Time."
                )
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .leavesChatRoom()
        .accessibilityIdentifier("analytics.subscriptions")
    }

    @ViewBuilder
    private var notices: some View {
        if showsBillingNotice, let lifecycle {
            AnalyticsNotice(
                tone: .warning,
                text: String(localized: "\(AnalyticsText.count(lifecycle.lost)) subscribers left in \(lifecycle.period.length) days because Apple couldn’t charge them. Billing Grace Period is off for \(appName)."),
                primary: (String(localized: "See Billing and Plans"), { onShow(.billing) }),
                identifier: "analytics.subscriptions.billingNotice"
            )
        }
        if hasPageRows {
            AnalyticsNotice(
                tone: .info,
                text: String(localized: "Apple now says which product page, campaign and source each subscriber came from."),
                primary: (String(localized: "Break It Down by Page"), onBreakDown),
                identifier: "analytics.subscriptions.originNotice"
            )
        }
    }

    /// Subscribers lost to failed charges while Billing Grace Period is off.
    private var showsBillingNotice: Bool {
        guard let lifecycle else { return false }
        return gracePeriod?.isOn == false && lifecycle.lost > 0
    }

    private var renewals: some View {
        box {
            header([String(localized: "Renewal rate"), String(localized: "Renewed"), String(localized: "Rate")])
            if report.renewals.isEmpty { empty(String(localized: "No renewals came due in this period.")) }
            ForEach(report.renewals) { renewal in
                Divider()
                HStack {
                    Text("\(renewal.subscription) · \(renewal.periodTitle)").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(AnalyticsText.count(renewal.renewed)) of \(AnalyticsText.count(renewal.due))")
                        .monospacedDigit().foregroundStyle(Palette.label2).frame(width: 90, alignment: .trailing)
                    RateLabel(rate: renewal.rate).frame(width: 110, alignment: .trailing)
                }
                .font(.callout)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.xSmall)
            }
        }
    }

    private var cancellations: some View {
        box {
            HStack {
                Text("Cancellations · \(AnalyticsText.count(report.cancellations))").font(.body.weight(.semibold))
                Spacer()
                Text("Apple’s reasons").font(.subheadline).foregroundStyle(Palette.label2)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.small)
            ForEach(report.reasons.filter { $0.count > 0 }) { reason in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(reason.name).font(.callout)
                        Text(reason.detail).font(.subheadline).foregroundStyle(Palette.label2).lineLimit(1)
                        Spacer(minLength: Spacing.small)
                        Text("\(AnalyticsText.count(reason.count)) · \(AnalyticsText.wholePercent(reason.share))").font(.callout).monospacedDigit()
                    }
                    MeterBar(fraction: reason.share, height: 4)
                }
                .padding(.horizontal, Spacing.medium)
                .accessibilityElement(children: .combine)
            }
            if report.cancellations > 0 {
                let early = String(
                    localized: "\(AnalyticsText.count(report.earlyCancellations)) of \(AnalyticsText.count(report.cancellations)) came before the first renewal."
                )
                HStack(spacing: Spacing.small) {
                    Text(liveRetentionMessages == 0 ? early + " " + String(localized: "No retention message is live.") : early)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Spacing.small)
                    Button("Open Retention") { onAct(.retention, early) }
                        .controlSize(.regular)
                        .accessibilityIdentifier("analytics.subscriptions.openRetention")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(liveRetentionMessages == 0 ? Palette.warnTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field))
                .padding(.horizontal, Spacing.medium)
            } else {
                empty(String(localized: "No cancellations in this period."))
            }
            Spacer(minLength: Spacing.small).frame(height: Spacing.small)
        }
    }

    private var products: some View {
        box {
            header([String(localized: "Subscription"), String(localized: "Active"), String(localized: "Trial → paid"), String(localized: "Proceeds")])
            ForEach(report.products) { product in
                Divider()
                HStack {
                    Text(product.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(product.active.map(AnalyticsText.count) ?? "—").monospacedDigit().frame(width: 70, alignment: .trailing)
                    RateLabel(rate: product.trialToPaid).frame(width: 110, alignment: .trailing)
                    Text(AnalyticsText.dollars(product.proceeds)).monospacedDigit().frame(width: 80, alignment: .trailing)
                }
                .font(.callout)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.xSmall)
            }
        }
    }

    private var territories: some View {
        box {
            header([String(localized: "Trial → paid by territory"), String(localized: "Paid"), String(localized: "Rate")])
            if report.territories.isEmpty { empty(String(localized: "No trials ended in this period.")) }
            ForEach(report.territories.prefix(12)) { row in
                Divider()
                HStack(spacing: Spacing.small) {
                    FlagTile(regionCode: row.code)
                    Text(row.name).lineLimit(1)
                    if row.trialToPaid.measured?.standing == .worse {
                        Button("Open Pricing for \(row.name)") {
                            onAct(.pricing(territory: row.code), String(localized: "\(row.name): \(row.paid) of \(row.ended) trials became paid."))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.accentText)
                        .font(.subheadline)
                    }
                    Spacer(minLength: 0)
                    Text(row.trialToPaid.isTooFew ? "" : "\(row.paid) of \(row.ended)")
                        .monospacedDigit().foregroundStyle(Palette.label2).frame(width: 80, alignment: .trailing)
                    RateLabel(rate: row.trialToPaid).frame(width: 110, alignment: .trailing)
                }
                .font(.callout)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.xSmall)
            }
        }
    }

    private func card(_ label: String, _ value: String, _ note: String) -> some View {
        Card(padding: Spacing.medium) {
            title(label)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(note).font(.subheadline).foregroundStyle(Palette.label2).monospacedDigit()
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.label2)
    }

    private func header(_ titles: [String]) -> some View {
        HStack {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title).frame(maxWidth: index == 0 ? .infinity : nil, alignment: .leading)
                    .frame(width: index == 0 ? nil : (titles.count == 4 && index != 2 ? 75 : 100), alignment: .trailing)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.label2)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(Palette.label2).padding(.horizontal, Spacing.medium).padding(.vertical, Spacing.small)
    }

    private func box(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) { content() }
            .padding(.bottom, Spacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
            .accessibilityElement(children: .contain)
    }
}
