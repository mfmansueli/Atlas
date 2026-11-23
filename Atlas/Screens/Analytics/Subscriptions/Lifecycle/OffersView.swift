//
//  OffersView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions → Offers: each offer by name, and how many of
/// the people it brought paid the regular price afterwards.
struct OffersView: View {
    let report: LifecycleReport?
    let onAct: (FindingAction, String) -> Void

    private static let widths: [CGFloat] = [110, 70, 100, 110, 160]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let report, !report.offers.isEmpty {
                    if let weak = report.offers.first(where: { $0.standing == .worse }) {
                        AnalyticsNotice(
                            tone: .warning,
                            text: String(localized: "\(weak.name) brought \(AnalyticsText.count(weak.started)) people and \(AnalyticsText.count(weak.paidAfterwards)) stayed at full price."),
                            primary: (String(localized: "Open Pricing"), { onAct(.pricing(territory: nil), weak.name) }),
                            identifier: "analytics.offers.weak"
                        )
                    }
                    table(report)
                    Text("""
                    Paid afterwards: people charged the regular price after the offer. A rate shows once the first \
                    people reach it. Covers every subscriber.
                    """)
                    .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(3)
                } else {
                    ContentUnavailableView(
                        "No offers in this period", systemImage: "gift",
                        description: Text("""
                        Introductory, promotional, win-back and retention offers and offer codes show here once Apple \
                        counts one.
                        """)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xLarge)
                }
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .accessibilityIdentifier("analytics.offers")
    }

    private func table(_ report: LifecycleReport) -> some View {
        AnalyticsBox(title: String(localized: "Offers"), trailing: report.offerAverage.map { String(localized: "Average \(AnalyticsText.percent($0))") }) {
            AnalyticsColumns(
                titles: [
                    String(localized: "Offer"), String(localized: "Type"), String(localized: "Started"), String(localized: "Paid afterwards"),
                    String(localized: "Rate"), String(localized: "Against average"),
                ],
                widths: Self.widths
            )
            ForEach(report.offers) { offer in
                Divider()
                AnalyticsColumns(
                    [
                        AnyView(Text(offer.name).fontWeight(.medium)),
                        AnyView(Text(Self.typeTitle(offer.type)).foregroundStyle(Palette.label2)),
                        AnyView(Text(AnalyticsText.count(offer.started))),
                        AnyView(Text(offer.isTooYoung ? "—" : AnalyticsText.count(offer.paidAfterwards))),
                        AnyView(rate(offer)),
                        AnyView(standing(offer)),
                    ],
                    widths: Self.widths
                )
                .accessibilityIdentifier("analytics.offers.row.\(offer.id)")
            }
        }
    }

    @ViewBuilder
    private func rate(_ offer: LifecycleReport.Offer) -> some View {
        if let renewal = offer.firstRenewal {
            Text("first renewals from \(AnalyticsText.day(renewal.date))").font(.subheadline).foregroundStyle(Palette.label2)
        } else {
            RateLabel(rate: offer.rate)
        }
    }

    @ViewBuilder
    private func standing(_ offer: LifecycleReport.Offer) -> some View {
        if offer.isTooYoung {
            Text("Still measuring").foregroundStyle(Palette.label2)
        } else if let standing = offer.standing {
            Text("\(standing.mark) \(standing.title)")
                .foregroundStyle(standing == .better ? Palette.ok : standing == .worse ? Palette.err : Palette.label2)
        } else {
            Text(offer.rate.isTooFew ? String(localized: "Too few to tell") : "—").foregroundStyle(Palette.label2)
        }
    }

    /// Apple's Offer Type, as Pricing names it.
    static func typeTitle(_ type: String) -> String {
        let value = type.lowercased()
        if value.contains("intro") || value.contains("free trial") { return String(localized: "Introductory") }
        if value.contains("win") { return String(localized: "Win-back") }
        if value.contains("retention") { return String(localized: "Retention") }
        if value.contains("code") { return String(localized: "Offer code") }
        if value.contains("promo") { return String(localized: "Promotional") }
        return type.isEmpty ? "—" : type
    }
}
