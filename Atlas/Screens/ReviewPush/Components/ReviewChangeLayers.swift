//
//  ReviewChangeLayers.swift
//  Atlas
//

import SwiftUI

/// What an assistant sent beside a change it queued, under its Review &
/// Push row (README-DS §9): MEANS for a text in another language and how
/// natural it sounds (board 77; In-App Texts and store texts proposed
/// straight into Review & Push), then its details folded under Details. How sure it is shows on the
/// row's title line, before the source tag.
struct ReviewChangeLayers: View {
    let layers: SuggestionLayers
    /// Who sent it, for the Sounds pill's tooltip.
    var client = String(localized: "the assistant", comment: "kind:description")

    var body: some View {
        if layers.gloss != nil || layers.details != nil || layers.translation?.sounds != nil {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                if let means = layers.means { TranslationMeansLine(means: means, drift: layers.translation?.drift ?? []) }
                if let translation = layers.translation, translation.sounds != nil {
                    TranslationSoundsBlock(translation: translation, client: client)
                }
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
