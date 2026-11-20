//
//  DebugInAppEventsData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Canned In-App Events for Lumen Journal, as on the design's board 40:
/// the Winter Reflection Challenge (a draft, written in English, Spanish
/// and Italian, with nine languages suggested by Claude Code), the Mood
/// Calendar event that goes with 1.4, and Gratitude Week, which ended.
enum DebugInAppEventsData {
    typealias AppIDs = DebugFixtures.AppID

    static let winterID = "event-winter"
    static let moodID = "event-mood"
    static let gratitudeID = "event-gratitude"
    /// Where Open on the Mood Calendar's card goes.
    static let moodDeepLink = "lumen://mood-calendar"
    static let client = DebugReviewsData.client

    static func date(month: Int, day: Int, hour: Int = 9) -> Date {
        Calendar.gmtGregorian.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .now
    }

    /// Every country and region, as App Store Connect lists an event's
    /// schedule: Atlas changes a draft's dates only when it knows them.
    static let territories = TerritoryCatalog.standard.territories.map(\.id)

    /// The languages the events are written in or suggested for.
    static let locales = ["en-US", "en-GB", "de-DE", "ja", "fr-FR", "es-ES", "es-MX", "it", "pt-BR", "ko", "zh-Hans", "ar-SA", "nl-NL", "sv"]

    /// Winter's texts the developer wrote: name, short, long.
    private static let written: [String: [String]] = [
        "en-US": [
            "Winter Reflection Challenge", "31 prompts to close the year gently",
            "Three lines a day through December. Each evening, a new prompt about the year behind you and the one ahead.",
        ],
        "en-GB": [
            "Winter Reflection Challenge", "31 prompts to close the year gently",
            "Three lines a day through December. Each evening, a new prompt about the year behind you and the one ahead.",
        ],
        "es-ES": [
            "Reto Reflexión de Invierno", "31 preguntas para cerrar el año con calma",
            "Tres líneas al día durante diciembre. Cada noche, una pregunta sobre el año que se va y el que llega.",
        ],
        "es-MX": [
            "Reto Reflexión de Invierno", "31 preguntas para cerrar el año con calma",
            "Tres líneas al día durante diciembre. Cada noche, una pregunta sobre el año que se va y el que llega.",
        ],
        "it": [
            "Sfida Riflessioni d’inverno", "31 spunti per chiudere l’anno con calma",
            "Tre righe al giorno per tutto dicembre. Ogni sera, uno spunto sull’anno passato e su quello che arriva.",
        ],
    ]

    /// Winter's suggested languages: name, short, long, why.
    private static let suggested: [String: [String]] = [
        "de-DE": [
            "Winter-Reflexion in 31 Tagen", "Mit 31 Impulsen sanft ins neue Jahr",
            "Drei Zeilen am Tag, den ganzen Dezember. Jeden Abend ein neuer Impuls zum alten und zum neuen Jahr.",
            "Uses “Impulse” for prompts, like your German store page.",
        ],
        "ja": [
            "冬のふりかえりチャレンジ", "31の問いで、一年をやさしく締めくくる",
            "12月は毎日3行だけ。毎晩、過ぎた一年とこれからの一年についての新しい問いが届きます。",
            "ふりかえり is the word your Japanese page uses for reflection.",
        ],
        "fr-FR": [
            "Défi Bilan d’hiver", "31 questions pour finir l’année en douceur",
            "Trois lignes par jour en décembre. Chaque soir, une question sur l’année passée et celle qui vient.",
            "Translated from English, in the voice of your French store page.",
        ],
        "pt-BR": [
            "Desafio de Fim de Ano", "31 perguntas para fechar o ano com calma",
            "Três linhas por dia em dezembro. Toda noite, uma pergunta sobre o ano que passou e o que vem por aí.",
            "In Brazil December is summer, so “winter” would feel wrong. Named after the end of the year instead.",
        ],
        "ko": [
            "겨울 회고 챌린지", "31개의 질문으로 한 해를 차분히 마무리",
            "12월 한 달, 하루 세 줄. 매일 저녁 지난 한 해와 다가올 한 해에 대한 새 질문이 도착해요.",
            "Translated from English, in the voice of your Korean store page.",
        ],
        "zh-Hans": [
            "冬日回顾挑战", "用 31 个问题温柔地告别这一年",
            "12 月每天写三行。每晚都会收到一个关于过去一年和新一年的问题。",
            "Translated from English, in the voice of your Chinese store page.",
        ],
        "ar-SA": [
            "تحدي تأملات الشتاء", "31 سؤالًا لختام العام بهدوء",
            "ثلاثة أسطر يوميًا طوال ديسمبر. كل مساء سؤال جديد عن العام الماضي والعام القادم.",
            "Translated from English. Right to left, checked against your Arabic page.",
        ],
        "nl-NL": [
            "Winterreflectie-uitdaging", "31 vragen om het jaar rustig af te sluiten",
            "Drie regels per dag in december. Elke avond een vraag over het jaar dat voorbij is en het jaar dat komt.",
            "Translated from English, in the voice of your Dutch store page.",
        ],
        "sv": [
            "Vinterreflektion i 31 dagar", "31 frågor för att avsluta året i lugn och ro",
            "Tre rader om dagen i december. Varje kväll en ny fråga om året som gått och året som kommer.",
            "Translated from English, in the voice of your Swedish store page.",
        ],
    ]

    private static let card = InAppEventMedia(kind: .card, width: 1920, height: 1080)
    private static let details = InAppEventMedia(kind: .details, width: 1080, height: 1920)

    private static func localizations(_ eventID: String, _ texts: [String: [String]], media: [InAppEventMedia]) -> [InAppEventLocalization] {
        locales.compactMap { locale in
            guard let text = texts[locale] else { return nil }
            return InAppEventLocalization(
                id: "\(eventID)-\(locale)", locale: locale, name: text[0], shortDescription: text[1], longDescription: text[2],
                media: locale == "en-US" ? media : []
            )
        }
    }

    /// The same text in every language: enough for an event that isn't
    /// the one being localized.
    private static func everywhere(_ text: [String]) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: locales.filter { $0 != "en-GB" && $0 != "es-MX" }.map { ($0, text) })
    }

    static let winter = InAppEvent(
        id: winterID, referenceName: "Winter Reflection 2026", badge: .challenge, state: .draft, primaryLocale: "en-US", priority: .normal,
        purpose: .appropriateForAllUsers,
        schedules: [InAppEventSchedule(
            territories: territories, publishStart: date(month: 11, day: 24), eventStart: date(month: 12, day: 1), eventEnd: date(month: 12, day: 31)
        )],
        localizations: localizations(winterID, written, media: [card])
    )

    static let mood = InAppEvent(
        id: moodID, referenceName: "1.4 Mood Calendar", badge: .majorUpdate, state: .draft, deepLink: moodDeepLink, primaryLocale: "en-US",
        priority: .high,
        purpose: .bringBackLapsedUsers,
        schedules: [InAppEventSchedule(
            territories: territories, publishStart: date(month: 11, day: 24), eventStart: date(month: 11, day: 24), eventEnd: date(month: 12, day: 8)
        )],
        localizations: localizations(moodID, everywhere([
            "Mood Calendar", "See your month in color", "Lumen 1.4 turns your entries into a calendar of moods, so you can see how your month really felt.",
        ]), media: [card, details])
    )

    static let gratitude = InAppEvent(
        id: gratitudeID, referenceName: "Gratitude Week", badge: .specialEvent, state: .past, primaryLocale: "en-US", priority: .normal,
        purpose: .appropriateForAllUsers,
        schedules: [InAppEventSchedule(publishStart: date(month: 10, day: 24), eventStart: date(month: 10, day: 31), eventEnd: date(month: 11, day: 7))],
        localizations: localizations(gratitudeID, everywhere([
            "Gratitude Week", "Seven days, seven thank-yous", "One small thank-you a day for a week, with a new prompt every evening.",
        ]), media: [card, details])
    )

    static let events = [winter, mood, gratitude]

    static let gratitudeResults = InAppEventResults(
        pageViews: 2140, opens: 1060, downloads: 312,
        note: "From Apple’s App Analytics, Oct 31 – Nov 7. Too few downloads in most countries to compare them."
    )

    static let suggestions: [InAppEventTextSuggestion] = locales.compactMap { locale in
        guard let text = suggested[locale] else { return nil }
        return InAppEventTextSuggestion(
            eventID: winterID, locale: locale, name: text[0], shortDescription: text[1], longDescription: text[2], why: text[3], source: client,
            date: DebugReviewsData.today
        )
    }

    /// Winter's nine suggested languages, waiting.
    @MainActor
    static func store(suggestions: [InAppEventTextSuggestion] = DebugInAppEventsData.suggestions) -> InAppEventsStore {
        let store = InAppEventsStore()
        store.load(InAppEventsArchive(suggestions: suggestions), for: AppIDs.lumen)
        return store
    }
}
#endif
