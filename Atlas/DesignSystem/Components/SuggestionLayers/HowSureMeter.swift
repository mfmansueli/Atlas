//
//  HowSureMeter.swift
//  Atlas
//

import SwiftUI

/// How sure a suggestion is: three small rising bars on the title line,
/// filled up to its confidence (README-DS §9). It has no text of its own:
/// VoiceOver and the tooltip say the fixed word (Not very sure · Fairly
/// sure · Sure), then `detail` when there is one: why, in a line or two
/// (the Analytics sureTip pattern).
struct HowSureMeter: View {
    let confidence: HowSure
    var detail: String?

    /// "Fairly sure", then the detail on the next line.
    var tip: String {
        guard let detail, !detail.isEmpty else { return confidence.word }
        return "\(confidence.word)\n\(detail)"
    }

    /// Bar heights, shortest first, as the prototype draws them (`.cm`).
    private static let heights: [CGFloat] = [4, 6.5, 9]

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(Self.heights.indices, id: \.self) { index in
                Capsule()
                    .fill(index < confidence.steps ? Palette.label2 : Palette.separator2)
                    .frame(width: 2.5, height: Self.heights[index])
            }
        }
        .frame(height: Self.heights[2], alignment: .bottom)
        .fixedSize()
        .help(Text(verbatim: tip))
        .accessibilityElement()
        .accessibilityLabel(Text(String(localized: "How sure", comment: "kind:accessibility-label")))
        .accessibilityValue(Text(confidence.word))
        .accessibilityHint(Text(verbatim: detail ?? ""))
        .accessibilityIdentifier("suggestion.howSure")
    }
}

#Preview {
    HStack(spacing: Spacing.medium) {
        ForEach(HowSure.allCases, id: \.self) { HowSureMeter(confidence: $0) }
    }
    .padding()
}
