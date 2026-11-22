//
//  MenuBarJobRow.swift
//  Atlas
//

import SwiftUI

/// One job under "Running now": what it is, a bar, and how far it is.
struct MenuBarJobRow: View {
    let job: BackgroundJob

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(job.title)
                .font(.system(size: 13, weight: .semibold))
            if let fraction = job.fraction {
                MenuBarProgressBar(fraction: fraction)
            }
            if !job.detail.isEmpty {
                Text(job.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(job.fraction.map { Text($0, format: .percent.precision(.fractionLength(0))) } ?? Text(""))
        .accessibilityIdentifier("menuBar.job.\(job.kind.rawValue)")
    }
}

#Preview {
    MenuBarJobRow(job: BackgroundJob(
        id: "push", kind: .push, title: "Pushing to App Store Connect", fraction: 0.61,
        detail: "14 of 23 changes · Lumen Journal · about 1 min left"
    ))
    .frame(width: 330)
}
