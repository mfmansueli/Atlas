//
//  AnalyticsWaitingView.swift
//  Atlas
//

import SwiftUI

/// Asked, waiting: when Apple was asked and when to expect the reports.
/// No spinner; this takes a day or two, not minutes.
struct AnalyticsWaitingView: View {
    let asked: Date
    /// When Atlas last looked for the reports; nil before the first look.
    var lastChecked: Date?
    var now: Date = .now
    let isChecking: Bool
    var errorMessage: String?
    let onCheck: () -> Void

    private var expected: Date { asked.addingTimeInterval(2 * 86400) }

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "clock")
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("Apple is preparing the reports")
                .font(.title2.weight(.semibold))
            Text("They usually arrive in 1 to 2 days. Asked on \(AnalyticsText.day(asked)), so expect them around \(AnalyticsText.day(expected)). Atlas checks every morning and lets you know when they’re here.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .fixedSize(horizontal: false, vertical: true)
            AnalyticsSetupSteps(steps: [
                .init(
                    title: String(localized: "Asked Apple"),
                    detail: String(localized: "\(AnalyticsText.day(asked)) · ongoing reports, plus a one-time snapshot of earlier data so comparisons can start right away"),
                    state: .done
                ),
                .init(title: String(localized: "Apple prepares the first reports"), detail: String(localized: "1 to 2 days"), state: .current),
                .init(
                    title: String(localized: "Atlas downloads them"),
                    detail: String(localized: "Every morning from then on. Numbers are always 1 to 2 days behind.")
                ),
            ])
            if let errorMessage { InlineMessage.error(errorMessage) }
            Text(checkedText)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("analytics.setup.waiting.checked")
            HStack(spacing: Spacing.medium) {
                Text("Everything else in Atlas works as usual meanwhile.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                Button("Check Now", action: onCheck)
                    .controlSize(.regular)
                    .disabled(isChecking)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.setup.waiting")
    }

    /// "Asked Apple today at 15:04 · Last checked today at 15:20: not there yet".
    private var checkedText: String {
        let askedText = String(localized: "Asked Apple \(AnalyticsText.moment(asked, now: now))")
        guard let lastChecked else { return askedText + " · " + String(localized: "Not checked yet") }
        return askedText + " · " + String(localized: "Last checked \(AnalyticsText.moment(lastChecked, now: now)): not there yet")
    }
}

#Preview {
    AnalyticsWaitingView(asked: .now, isChecking: false, onCheck: {})
        .padding()
        .frame(width: 900, height: 560)
}
