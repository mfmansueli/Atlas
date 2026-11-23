//
//  PhasedReleaseBars.swift
//  Atlas
//

import SwiftUI

/// The 7 days of a phased release, the days so far filled.
struct PhasedReleaseBars: View {
    let day: Int
    let isPaused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(1...PhasedRelease.dayCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: Radius.flag)
                        .fill(index <= day ? (isPaused ? Palette.label3 : Palette.accentTint) : Palette.fill2)
                        .frame(height: 6)
                }
            }
            Text(isPaused
                ? String(localized: "Phased release paused on day \(day) of \(PhasedRelease.dayCount)")
                : String(localized: "Day \(day) of \(PhasedRelease.dayCount) · \(PhasedRelease.percentage(day: day))% of automatic updates"))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .combine)
    }
}
