//
//  NativeTranslationDebugData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// A `begin_translation` run for Lumen Journal 1.4: the subtitle and
/// promotional text in German, French, Japanese and Portuguese (Brazil),
/// one native-speaker agent per language. Each language's suggestions
/// arrive when its writer is done; it counts once its reviewer ends it.
@MainActor
enum NativeTranslationDebugData {
    static let languages: [StoreLocale] = [.german, .french, .japanese, .portugueseBrazil]
    static let fields: [ListingField] = [.subtitle, .promotionalText]

    /// How far the run got.
    enum Stage {
        /// German reviewed and ended, French written, the others coming:
        /// "Translating · 1 of 4 languages".
        case working
        /// Every language written; Portuguese (Brazil) still in review.
        case lastInReview
    }

    static func store(_ stage: Stage) -> FieldSuggestionStore {
        let store = FieldSuggestionStore()
        let plan = languages.flatMap { locale in fields.map { SuggestionTarget.storePage(locale, $0) } }
        let run = store.startRun(
            appID: SuggestionsDebugData.appID, client: SuggestionsDebugData.client, plan: plan, kind: .translation,
            languages: languages.map(\.code)
        )
        let written: [StoreLocale] = stage == .working ? [.german, .french] : languages
        for locale in written {
            for field in fields {
                guard let value = texts[locale.code]?[field] else { continue }
                store.add(
                    appID: SuggestionsDebugData.appID,
                    target: .storePage(locale, field),
                    value: value,
                    reason: "Written by a native \(locale.name) copywriter; keeps “Lumen”.",
                    source: .assistant(client: SuggestionsDebugData.client),
                    runID: run.id
                )
            }
        }
        let ended: [StoreLocale] = stage == .working ? [.german] : [.german, .french, .japanese]
        for locale in ended {
            store.endLanguage(locale.code, inRun: run.id)
        }
        return store
    }

    /// The last language's reviewer ends it, which finishes the run.
    static func endLast(in store: FieldSuggestionStore) {
        guard let run = store.run else { return }
        store.endLanguage(StoreLocale.portugueseBrazil.code, inRun: run.id)
    }

    /// What each language's writer sent.
    private static let texts: [String: [ListingField: String]] = [
        "de-DE": [
            .subtitle: "Private Notizen, sanfte Fragen",
            .promotionalText: "Neu: Wöchentliche Rückblicke – jeden Sonntag ein ruhiger Blick zurück auf deine Woche.",
        ],
        "fr-FR": [
            .subtitle: "Notes privées, douces pistes",
            .promotionalText: "Nouveau : le Bilan de la semaine, un moment calme chaque dimanche pour revoir vos sept jours.",
        ],
        "ja": [
            .subtitle: "心を整える、やさしい日記",
            .promotionalText: "新機能：週ごとのふり返り。日曜日に一週間を静かに見つめ直せます。",
        ],
        "pt-BR": [
            .subtitle: "Notas privadas, ideias leves",
            .promotionalText: "Novidade: Reflexões da Semana, um olhar tranquilo para os seus dias todo domingo.",
        ],
    ]
}
#endif
