//
//  GlossLine.swift
//  Atlas
//

import SwiftUI

/// What a text in another language means, under it: "Means: Your week on
/// one calm page" (README-DS §9, the gloss). Always in the same place on a
/// card: after the why, before the actions.
struct GlossLine: View {
    let gloss: String

    var body: some View {
        Text(String(localized: "Means: \(gloss)", comment: "kind:description"))
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityIdentifier("suggestion.gloss")
    }
}

#Preview {
    GlossLine(gloss: "Your week on one calm page")
        .padding()
        .frame(width: 360)
}
