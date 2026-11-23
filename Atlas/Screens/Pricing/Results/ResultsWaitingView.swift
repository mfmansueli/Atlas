//
//  ResultsWaitingView.swift
//  Atlas
//

import SwiftUI

/// Results before the 28 days are up: when prices changed, when results
/// arrive and why it takes that long, with the days so far.
struct ResultsWaitingView: View {
    let changedOn: Date
    let day: Int
    let arrivesOn: Date

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Too early to tell")
                .font(.title3.weight(.semibold))
            Text("""
            Prices changed on \(PricingText.date(changedOn)). Results arrive \(PricingText.date(arrivesOn)): 28 days covers a monthly \
            billing cycle and Apple’s report delay.
            """)
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Spacing.xSmall) {
                MeterBar(fraction: Double(day) / Double(ResultsEvaluator.windowDays), tint: Palette.accent)
                    .accessibilityLabel(String(localized: "Days until results"))
                Text("Day \(day) of \(ResultsEvaluator.windowDays)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
            }
            .frame(width: 300)
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.results.waiting")
    }
}
