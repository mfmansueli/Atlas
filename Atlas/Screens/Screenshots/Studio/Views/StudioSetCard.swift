//
//  StudioSetCard.swift
//  Atlas
//

import SwiftUI

/// "Live set" or "New set": how it was made, languages, iPad and checks,
/// with the way to Sets, Template and Captions. A new set waits in the
/// toolbar's Review & Push, the only push (board 57).
struct StudioSetCard: View {
    let summary: StudioSetSummary
    let onOpenSets: () -> Void

    var body: some View {
        Card {
            HStack {
                Text(summary.title)
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("studio.setCard.title")
                Spacer()
                Pill(text: summary.pill, style: summary.pillStyle)
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.xSmall) {
                ForEach(summary.lines) { line in
                    GridRow {
                        Text(line.label)
                            .foregroundStyle(Palette.label2)
                            .gridColumnAlignment(.leading)
                        Text(line.value)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
                }
            }
            HStack(spacing: Spacing.small) {
                Button("Sets, Template and Captions", action: onOpenSets)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("studio.setCard.openSets")
            }
            .padding(.top, Spacing.xxSmall)
        }
        .accessibilityIdentifier("studio.setCard")
    }
}
