//
//  ReviewChangeLayers.swift
//  Atlas
//

import SwiftUI

/// What an assistant sent beside a change it queued, under its Review &
/// Push row (README-DS §9): "Means: …" for a text in another language,
/// then its details folded under Details. How sure it is shows on the
/// row's title line, before the source tag.
struct ReviewChangeLayers: View {
    let layers: SuggestionLayers

    var body: some View {
        if layers.gloss != nil || layers.details != nil {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                if let gloss = layers.gloss { GlossLine(gloss: gloss) }
                if let details = layers.details { SuggestionDetailsDisclosure(details: details) }
            }
            .padding(.leading, 26)
        }
    }
}

#Preview {
    ReviewChangeLayers(layers: SuggestionLayers(
        details: "Searches for „Tagebuch“ grew 40% in Germany this year; the old subtitle had none of them.",
        confidence: .fairlySure,
        gloss: "Your journal, calm and private"
    ))
    .padding()
    .frame(width: 560)
}
