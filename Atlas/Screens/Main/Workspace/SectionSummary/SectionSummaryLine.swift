//
//  SectionSummaryLine.swift
//  Atlas
//

import SwiftUI

/// The summary line under a section's description, in the accent's text
/// colour: “3 suggestions · about 2 min · 2 in Review & Push”. Draws
/// nothing without a summary in the environment.
struct SectionSummaryLine: View {
    @Environment(\.sectionSummary) private var summary

    var body: some View {
        if let summary, !summary.isEmpty {
            Text(summary.text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Palette.accentText)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel(Text(summary.accessibilityText))
                .accessibilityIdentifier("section.summary")
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        SectionSummaryLine()
            .environment(\.sectionSummary, SectionSummary(suggestions: 3, notPushed: 2))
        SectionSummaryLine()
            .environment(\.sectionSummary, SectionSummary(suggestions: 1, notPushed: 0))
    }
    .padding()
}
