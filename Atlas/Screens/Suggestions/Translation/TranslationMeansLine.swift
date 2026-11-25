//
//  TranslationMeansLine.swift
//  Atlas
//

import SwiftUI

/// MEANS and its text on one line, for cards that don't lay Now and
/// Suggested out in a grid (captions, In-App Events, Accept All).
struct TranslationMeansLine: View {
    let means: String
    var drift: [MeaningDrift] = []
    /// The label column's width, to line up with the card's Now and New.
    var labelWidth: CGFloat?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            TranslationMeansLabel()
                .frame(width: labelWidth, alignment: .leading)
            TranslationMeansText(means: means, drift: drift)
        }
        .accessibilityElement(children: .combine)
    }
}
