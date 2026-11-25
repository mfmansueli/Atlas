//
//  TranslationMeansText.swift
//  Atlas
//

import SwiftUI

/// What a suggestion in another language says, in the interface language:
/// MEANS's text, always left to right, with the words that moved away from
/// the original underlined in amber and the original in the tooltip.
struct TranslationMeansText: View {
    let means: String
    var drift: [MeaningDrift] = []

    var body: some View {
        Text(TranslationMarks.marked(means, phrases: drift.map(\.phrase)))
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
            .help(drift.map(TranslationReading.tooltip(for:)).joined(separator: "\n"))
            .accessibilityIdentifier("suggestion.means")
    }
}
