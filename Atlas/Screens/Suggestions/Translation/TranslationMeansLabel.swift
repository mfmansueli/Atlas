//
//  TranslationMeansLabel.swift
//  Atlas
//

import SwiftUI

/// "MEANS", beside Now and Suggested (board 77). The word stays the same
/// in every interface language.
struct TranslationMeansLabel: View {
    var body: some View {
        Text(verbatim: "MEANS")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.label2)
            .help(Text("What it says, in the language Atlas is in", comment: "kind:tooltip"))
            .accessibilityLabel(Text("Means", comment: "kind:accessibility-label"))
    }
}
