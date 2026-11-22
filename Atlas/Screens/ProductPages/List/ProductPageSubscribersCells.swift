//
//  ProductPageSubscribersCells.swift
//  Atlas
//

import SwiftUI

/// A page's two subscriber columns: "24 of 58 trials" and trial → paid
/// against every page together.
struct ProductPageSubscribersCells: View {
    let subscribers: SubscriberCounts?
    let average: Double?
    let widths: (subscribers: CGFloat, rate: CGFloat)

    var body: some View {
        if let subscribers {
            VStack(alignment: .leading, spacing: 1) {
                Text(AnalyticsText.count(subscribers.paid)).font(.callout.weight(.semibold)).monospacedDigit()
                Text("\(AnalyticsText.count(subscribers.trialConverted)) of \(AnalyticsText.count(subscribers.trialsEnded)) trials")
                    .font(.caption).foregroundStyle(Palette.label2).monospacedDigit().lineLimit(1)
            }
            .frame(width: widths.subscribers, alignment: .leading)
            .accessibilityElement(children: .combine)
            RateLabel(rate: subscribers.trialToPaid(average: average))
                .frame(width: widths.rate, alignment: .leading)
        } else {
            Text("—").foregroundStyle(Palette.label3).frame(width: widths.subscribers, alignment: .leading)
            Color.clear.frame(width: widths.rate, height: 1)
        }
    }
}
