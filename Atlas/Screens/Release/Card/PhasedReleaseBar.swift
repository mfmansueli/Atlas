//
//  PhasedReleaseBar.swift
//  Atlas
//

import SwiftUI

/// The 7 days of a phased release: the share of automatic updates that
/// have the version each day, with today marked.
struct PhasedReleaseBar: View {
    /// 1 to 7.
    let day: Int
    let isPaused: Bool

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            ForEach(Array(PhasedRelease.percentages.enumerated()), id: \.offset) { index, share in
                VStack(alignment: .leading, spacing: 2) {
                    Capsule()
                        .fill(color(index + 1))
                        .frame(height: 6)
                    Text("\(share)%")
                        .font(.footnote.monospacedDigit())
                    Text("Day \(index + 1)")
                        .font(.footnote)
                        .foregroundStyle(Palette.label2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Phased Release, 7 days"))
        .accessibilityValue(Text(isPaused ? "Paused on day \(day), \(PhasedRelease.percentage(day: day))%" : "Day \(day), \(PhasedRelease.percentage(day: day))%"))
        .accessibilityIdentifier("overview.version.phased")
    }

    private func color(_ index: Int) -> Color {
        if index < day { return Palette.ok }
        if index == day { return isPaused ? Palette.warnMark : Palette.accent }
        return Palette.fill2
    }
}

#Preview {
    VStack(spacing: 20) {
        PhasedReleaseBar(day: 3, isPaused: false)
        PhasedReleaseBar(day: 3, isPaused: true)
    }
    .frame(width: 420)
    .padding()
}
