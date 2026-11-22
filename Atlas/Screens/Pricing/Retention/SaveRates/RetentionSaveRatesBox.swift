//
//  RetentionSaveRatesBox.swift
//  Atlas
//

import SwiftUI

/// Under the messages: Apple's plain screen (No Message) as the
/// reference, and how often each retention offer was redeemed.
struct RetentionSaveRatesBox: View {
    let report: RetentionReport

    private static let widths: [CGFloat] = [56, 70, 64]

    private var offers: [RetentionReport.Message] {
        report.messages.filter { $0.offerName != nil && !$0.isNoMessage }
    }

    var body: some View {
        RetentionBox(title: String(localized: "Save rates · 28 days")) {
            EmptyView()
        } content: {
            if let none = report.messages.first(where: \.isNoMessage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Message").font(.body.weight(.medium))
                    Text("Apple’s plain screen, where no message applies: the reference")
                        .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(2)
                    RetentionSaveRateLine(measured: none)
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .accessibilityIdentifier("retention.saveRates.noMessage")
            }
            if !offers.isEmpty {
                Divider()
                AnalyticsColumns(
                    titles: [String(localized: "Retention offer"), String(localized: "Shown"), String(localized: "Redeemed"), String(localized: "Rate")],
                    widths: Self.widths
                )
                ForEach(offers) { message in
                    AnalyticsColumns(
                        [
                            AnyView(Text(message.offerName ?? message.name)),
                            AnyView(Text(AnalyticsText.count(message.opened))),
                            AnyView(Text(AnalyticsText.count(message.redeemed))),
                            AnyView(Text(message.opened > 0 ? AnalyticsText.percent(Double(message.redeemed) / Double(message.opened)) : "—")),
                        ],
                        widths: Self.widths
                    )
                }
            }
        }
        .accessibilityIdentifier("retention.saveRates")
    }
}
