//
//  RateLabel.swift
//  Atlas
//

import SwiftUI

/// A rate as every Analytics view writes it: "5.4% ▼" with the confidence
/// meter, the counts in the tertiary color when they're too few to tell,
/// or a dash when Apple doesn't give it. Only "worse" has a color.
struct RateLabel: View {
    let rate: AnalyticsRate
    /// The tooltip and VoiceOver value.
    var detail: String?
    var font: Font = .callout

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            switch rate {
            case .missing:
                Text("—").foregroundStyle(Palette.label2)
            case .tooFew:
                Text(rate.text).foregroundStyle(Palette.label2)
            case let .measured(measured):
                Text(rate.text)
                if let standing = measured.standing {
                    Text(standing.mark)
                        .font(.system(size: 10))
                        .foregroundStyle(Self.color(for: standing))
                }
                ConfidenceMeter(bars: measured.bars)
            }
        }
        .font(font)
        .monospacedDigit()
        .lineLimit(1)
        .help(detail ?? rate.detail())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(detail ?? rate.detail()))
    }

    static func color(for standing: RateStanding) -> Color {
        switch standing {
        case .better: Palette.label
        case .worse: Palette.warning
        case .same: Palette.label3
        }
    }
}

#Preview {
    VStack(alignment: .trailing) {
        RateLabel(rate: AnalyticsStatistics.rate(count: 260, total: 1480, average: 0.316))
        RateLabel(rate: AnalyticsStatistics.rate(count: 1190, total: 3610, average: 0.316))
        RateLabel(rate: AnalyticsStatistics.rate(count: 1, total: 40, average: 0.316))
        RateLabel(rate: .missing)
    }
    .padding()
}
