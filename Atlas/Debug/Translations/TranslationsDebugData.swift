//
//  TranslationsDebugData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Board 77's sample readings: Claude Code's second read, as a native
/// speaker, of Lumen Journal's suggestions in other languages. German
/// What's New sounds translated (two phrases), Polish and Turkish
/// subtitles sound off ("inspiracje" isn't "prompts"), Japanese and the
/// rest sound native; keywords have MEANS only. Built over
/// `NewLanguagesDebugData.store()`, so Polish, Turkish and Hebrew are the
/// project's new pages.
@MainActor
enum TranslationsDebugData {
    static var appID: StoreApp.ID { DebugFixtures.AppID.lumen }

    static func store() -> FieldSuggestionStore {
        let store = NewLanguagesDebugData.store()
        for (target, layers) in readings {
            guard let open = store.open(for: appID).first(where: { $0.target == target }) else { continue }
            store.add(appID: appID, target: target, value: open.value, reason: open.reason, source: open.source, layers: layers)
        }
        return store
    }

    /// The open suggestion for `field` in `locale`.
    static func suggestion(_ field: ListingField, in locale: StoreLocale, of store: FieldSuggestionStore) -> FieldSuggestion? {
        store.open(for: appID).first { $0.target == .storePage(locale, field) }
    }

    private static func layers(
        _ sounds: SoundsNatural?, _ means: String, drift: [MeaningDrift] = [], notes: [TranslationNote] = [],
        natural: String? = nil, naturalMeans: String? = nil
    ) -> SuggestionLayers {
        SuggestionLayers(
            gloss: means,
            translation: TranslationReading(sounds: sounds, notes: notes, natural: natural, naturalMeans: naturalMeans, drift: drift)
        )
    }

    private static let subtitleOff = "Means inspiration, not writing prompts."

    private static var readings: [(SuggestionTarget, SuggestionLayers)] {
        [
            (.storePage(.german, .whatsNew), layers(
                .translated,
                "• Weekly review: a calm summary of your week, every Sunday\n• Faster search over years of entries\n"
                    + "• Fixes the iCloud syncing on older devices",
                notes: [
                    TranslationNote(
                        phrase: "über Jahre an Einträgen", natural: "in Einträgen aus vielen Jahren",
                        why: "English word order (“across years of entries”)."
                    ),
                    TranslationNote(
                        phrase: "Behebt die iCloud-Synchronisierung", natural: "Fehler bei der iCloud-Synchronisierung … behoben",
                        why: "Reads as if it removes the sync. German notes say the bug was fixed."
                    ),
                ],
                natural: """
                • Wochenrückblick: jeden Sonntag eine ruhige Zusammenfassung deiner Woche
                • Schnellere Suche in Einträgen aus vielen Jahren
                • Fehler bei der iCloud-Synchronisierung auf älteren Geräten behoben
                """,
                naturalMeans: "• Weekly review: every Sunday, a calm summary of your week\n• Faster search in entries from many years\n"
                    + "• Fixed a bug with iCloud syncing on older devices"
            )),
            (.storePage(.german, .keywords), layers(nil, "diary, mood, gratitude, reflection, writing, mindfulness, habit, memories, journal")),
            (.storePage(.japanese, .whatsNew), layers(
                .native,
                "• Weekly look-back: every Sunday, a calm summary of your week\n• Search years of records quickly\n• Fixed iCloud sync on older devices"
            )),
            (.storePage(.polish, .name), layers(.native, "Lumen — Journal")),
            (.storePage(.polish, .subtitle), layers(
                .off, "Mood journal and inspirations",
                drift: [MeaningDrift(phrase: "inspirations", original: "prompts")],
                notes: [TranslationNote(phrase: "inspiracje", natural: "podpowiedzi", why: "\(subtitleOff) Polish journaling apps say “podpowiedzi”.")],
                natural: "Dziennik nastroju, podpowiedzi", naturalMeans: "Mood journal, prompts"
            )),
            (.storePage(.polish, .promotionalText), layers(
                .native, "Write a little every day. Lumen keeps your entries private and syncs them on all your devices."
            )),
            (.storePage(.polish, .description), layers(
                .native, "Lumen is a calm place to write. Write down one sentence or a whole page, track your mood and come back to what matters."
            )),
            (.storePage(.polish, .keywords), layers(nil, "journal, diary, mood, gratitude, writing, habits, memories, planner")),
            (.storePage(.polish, .whatsNew), layers(
                .native,
                "• Weekly summary: a calm review of the week every Sunday\n• Faster search in entries from many years\n• Fixed iCloud syncing on older devices"
            )),
            (.storePage(.turkish, .subtitle), layers(
                .off, "Mood diary and inspirations",
                drift: [MeaningDrift(phrase: "inspirations", original: "prompts")],
                notes: [
                    TranslationNote(phrase: "ilhamlar", natural: "öneriler", why: "A stiff plural of “inspiration”. Turkish apps say “öneriler”."),
                ],
                natural: "Ruh hali günlüğü ve öneriler", naturalMeans: "Mood diary and suggestions"
            )),
            (.storePage(.hebrew, .name), layers(.native, "Lumen — Journal")),
            (.storePage(.hebrew, .subtitle), layers(
                .translated, "Mood journal and inspiration",
                notes: [
                    TranslationNote(phrase: "והשראה", natural: "ושאלות לכתיבה", why: "Vague in Hebrew here. Journaling apps name the writing questions."),
                ],
                natural: "יומן מצב רוח ושאלות לכתיבה", naturalMeans: "Mood journal and writing questions"
            )),
            (.storePage(.hebrew, .promotionalText), layers(
                .native, "Write a little every day. Lumen keeps your entries private and syncs them on all your devices."
            )),
            (.storePage(.hebrew, .keywords), layers(nil, "journal, mood, gratitude, writing, habits, memories")),
        ]
    }

    // MARK: - Screenshot captions

    /// p77: French and German captions with their readings: "une page
    /// apaisée" reads as "a calmed-down page"; a German caption follows the
    /// English too closely.
    static var captionProposal: ScreenshotProposal {
        let french = CaptionProposalItem(
            locale: "fr-FR", slot: 0, headline: "Ta semaine sur une page apaisée", gloss: "Your week on a calmed-down page",
            translation: TranslationReading(
                sounds: .translated,
                notes: [TranslationNote(phrase: "une page apaisée", natural: "une page calme", why: "“Apaisée” is said of someone who calmed down.")],
                natural: "Ta semaine sur une page calme", naturalMeans: "Your week on one calm page"
            )
        )
        let german = CaptionProposalItem(
            locale: "de-DE", slot: 2, headline: "Jahre an Einträgen in Sekunden finden", gloss: "Find years of entries in seconds",
            translation: TranslationReading(
                sounds: .translated,
                notes: [
                    TranslationNote(
                        phrase: "Jahre an Einträgen", natural: "Einträge aus Jahren",
                        why: "Copies “years of entries”. German says entries from years."
                    ),
                ],
                natural: "Einträge aus Jahren in Sekunden finden", naturalMeans: "Find entries from years in seconds"
            )
        )
        let germanNative = CaptionProposalItem(
            locale: "de-DE", slot: 4, headline: "Privat. Nur auf deinen Geräten.", gloss: "Private. Only on your devices.",
            translation: TranslationReading(sounds: .native)
        )
        return .captions(
            id: "p77", client: ScreenshotsSampleData.assistant, receivedAt: ScreenshotsSampleData.today(10, 44), title: "Captions read again",
            reason: "Read again as a native speaker: two captions follow the English too closely.",
            items: [french, german, germanNative]
        )
    }
}
#endif
