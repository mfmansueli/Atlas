//
//  DebugProductPagesData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Lumen Journal's product pages, as on the design canvas (boards 50–55):
/// five pages in App Store Connect, Private diary made in Atlas, two pages
/// Claude Code suggested, and German and Japanese texts for Private diary.
enum DebugProductPagesData {
    static let appID = DebugFixtures.AppID.lumen

    enum PageID {
        static let prompts = "45812c9b-7d1e-4f0a-9c3b-2e61a0b8d4f7"
        static let mood = "9a03e6d2-51c8-4b7e-8f12-c47d90a6b3e1"
        static let sleep = "c7f2b18e-0a94-4d63-b5e7-183fa2c60d95"
        static let year = "e19d4c70-6b2f-4a85-9d31-70c5e8f2a164"
        static let therapists = "2f6a81d3-c4e9-47b0-a1d5-9b03e7c256f8"
        static let privateDiary = "draft-private-diary"
    }

    /// The scenes' day, and the last day with numbers (Nov 9).
    static let now = DebugReviewsData.today
    static let numbersThrough = Calendar(identifier: .gregorian).date(from: DateComponents(
        timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 11, day: 9, hour: 12
    )) ?? now

    static let locales = ["en-US", "de-DE", "ja", "fr-FR", "es-ES", "it", "pt-BR", "ko", "zh-Hans", "ar-SA", "nl-NL", "sv"]

    // MARK: - The default page

    /// Version 1.3's keywords, in its order.
    static let approvedKeywords: [String: [String]] = [
        "en-US": ["journal", "diary", "private", "prompts", "mood", "gratitude", "reflection", "daily", "notes", "lock", "habit", "mindful"],
        "de-DE": [
            "tagebuch", "journal", "privat", "schreibimpulse", "stimmung", "dankbarkeit", "reflexion", "täglich", "notizen", "sperre",
            "gewohnheit", "achtsamkeit",
        ],
        "ar-SA": ["يوميات", "مذكرات", "خاص", "مزاج", "امتنان", "تأمل", "يومي", "قفل"],
        "ja": ["日記", "ジャーナル", "プライベート", "気分", "感謝", "振り返り", "毎日", "ロック"],
    ]

    static let defaultTexts: [String: String] = [
        "en-US": "Write a little every day. Lumen keeps your entries private and synced across your devices.",
        "de-DE": "Schreib jeden Tag ein wenig. Lumen hält deine Einträge privat und auf all deinen Geräten synchron.",
        "ar-SA": "اكتب قليلاً كل يوم. Lumen يحافظ على خصوصية مدخلاتك ومزامنتها عبر أجهزتك.",
    ]

    static var defaultPage: ProductPageDefault {
        ProductPageDefault(
            versionID: "6450200014", versionString: "1.4", approvedVersionString: "1.3",
            languages: locales.map { locale in
                ProductPageDefaultLanguage(
                    id: "loc-\(locale)", locale: locale,
                    promotionalText: defaultTexts[locale] ?? defaultTexts["en-US"] ?? "",
                    approvedKeywords: approvedKeywords[locale] ?? []
                )
            }
        )
    }

    // MARK: - Pages

    static func link(_ id: String) -> URL? {
        URL(string: "https://apps.apple.com/app/lumen-journal/id6471234567?ppid=\(id)")
    }

    private static func localizations(_ page: String, _ codes: [String], texts: [String: String] = [:], keywords: [String: [String]] = [:],
                                      ownScreenshots: Set<String> = []) -> [ProductPageLocalization]
    {
        codes.map { locale in
            ProductPageLocalization(
                id: "\(page)-\(locale)", locale: locale, promotionalText: texts[locale] ?? "", keywords: keywords[locale] ?? [],
                screenshotDisplayTypes: ownScreenshots.contains(locale) ? ["APP_IPHONE_67"] : []
            )
        }
    }

    static var pages: [ProductPage] {
        [
            ProductPage(
                id: PageID.prompts, name: "Prompts", url: link(PageID.prompts), isVisible: true,
                versions: [ProductPageVersion(
                    id: "prompts-v1", number: 1, state: .approved, deepLink: "https://lumen.app/prompts/today",
                    localizations: localizations(
                        "prompts", locales,
                        texts: ["en-US": "A new prompt every evening, written for the day you had. Start with one line."],
                        keywords: ["en-US": ["journal", "prompts", "daily"], "de-DE": ["journal", "schreibimpulse"]],
                        ownScreenshots: ["en-US"]
                    )
                )]
            ),
            ProductPage(
                id: PageID.mood, name: "Mood tracking", url: link(PageID.mood), isVisible: true,
                versions: [ProductPageVersion(
                    id: "mood-v1", number: 1, state: .approved, deepLink: "https://lumen.app/mood",
                    localizations: localizations(
                        "mood", Array(locales.prefix(6)),
                        texts: ["en-US": "Made for this audience. Start with one line a day."],
                        keywords: ["en-US": ["mood", "habit"], "de-DE": ["stimmung"]]
                    )
                )]
            ),
            ProductPage(
                id: PageID.sleep, name: "Sleep & wind-down", url: link(PageID.sleep), isVisible: true,
                versions: [
                    ProductPageVersion(
                        id: "sleep-v1", number: 1, state: .approved, deepLink: "https://lumen.app/wind-down",
                        localizations: localizations("sleep", Array(locales.prefix(4)), keywords: ["en-US": ["notes", "mindful"]])
                    ),
                    ProductPageVersion(
                        id: "sleep-v2", number: 2, state: .inReview, deepLink: "https://lumen.app/wind-down",
                        localizations: localizations("sleep2", Array(locales.prefix(4)), keywords: ["en-US": ["notes", "mindful"]])
                    ),
                ]
            ),
            ProductPage(
                id: PageID.year, name: "Year in review", url: link(PageID.year), isVisible: false,
                versions: [ProductPageVersion(id: "year-v1", number: 1, state: .rejected, localizations: localizations("year", locales))]
            ),
            ProductPage(
                id: PageID.therapists, name: "Therapists", url: link(PageID.therapists), isVisible: false,
                versions: [ProductPageVersion(
                    id: "therapists-v1", number: 1, state: .approved, localizations: localizations("therapists", ["en-US", "de-DE"])
                )]
            ),
        ]
    }

    static var snapshot: ProductPagesSnapshot {
        ProductPagesSnapshot(pages: pages, defaultPage: defaultPage, readAt: now)
    }

    /// Private diary: made in Atlas, not pushed yet.
    static var privateDiary: ProductPageDraft {
        ProductPageDraft(
            id: PageID.privateDiary, name: "Private diary", start: .defaultPage,
            note: """
            People who want a diary nobody else can read. Lead with the Face ID lock and that entries stay on the device. For a \
            Search Ads campaign.
            """,
            locales: ["en-US", "de-DE", "ja", "ar-SA"],
            promotionalTexts: [
                "en-US": "Your diary, locked with Face ID. Entries stay on your devices and sync privately through iCloud.",
                "ar-SA": "يومياتك، مقفلة ببصمة الوجه. تبقى مدخلاتك على أجهزتك وتتم مزامنتها بشكل خاص عبر iCloud.",
            ],
            keywords: [
                "en-US": ["private", "diary", "lock"], "de-DE": ["privat", "tagebuch", "sperre"],
                "ar-SA": ["خاص", "مذكرات", "قفل"], "ja": ["プライベート", "日記"],
            ],
            deepLink: "https://lumen.app/lock",
            createdAt: now
        )
    }

    /// Its creation change in Review & Push.
    static var pendingChanges: [PendingChange] {
        [ProductPageChangeBuilder(appID: appID).newPageChange(privateDiary, defaultPage: defaultPage)].compactMap(\.self)
    }

    // MARK: - Suggestions

    static var pageSuggestions: [ProductPageSuggestion] {
        let languages = Dictionary(uniqueKeysWithValues: locales.map { ($0, "") })
        return [
            ProductPageSuggestion(
                id: "weekly", name: "Weekly reflections",
                audience: "For people who want a look back at their week, not a daily habit",
                reason: "Your product page test “Weekly Reflections first” downloads 18% better than the original (94% likely).",
                evidence: [SuggestionEvidence(kind: "analytics", ref: "Product Page test")],
                keywords: ["en-US": ["reflection", "habit", "mindful"]],
                promotionalTexts: languages.merging([
                    "en-US": "Every Sunday, Lumen gathers your week on one calm page: your best moments, your mood, the words you used most.",
                ]) { _, new in new },
                screens: "Weekly Reflections first, then Mood, Search, Write, Private",
                deepLink: "https://lumen.app/reflections", source: "Claude Code", createdAt: Self.now
            ),
            ProductPageSuggestion(
                id: "grat", name: "Gratitude journal",
                audience: "For people searching for a gratitude practice",
                reason: "“Gratitude” is in 23 of your last 220 reviews and in version 1.3’s keywords, and no page shows the Gratitude prompts first.",
                evidence: [SuggestionEvidence(kind: "reviews", ref: ""), SuggestionEvidence(kind: "keywords", ref: "of 1.3")],
                keywords: ["en-US": ["gratitude", "daily", "notes"]],
                promotionalTexts: languages.merging([
                    "en-US": "Three good things, every evening. Lumen’s gratitude prompts take a minute and stay private on your devices.",
                ]) { _, new in new },
                screens: "Prompts first, with the Gratitude prompt showing",
                deepLink: "https://lumen.app/gratitude", source: "Claude Code", createdAt: Self.now
            ),
        ]
    }

    static var textSuggestions: [ProductPageTextSuggestion] {
        [
            ProductPageTextSuggestion(
                pageID: PageID.privateDiary, locale: "de-DE",
                text: """
                Dein Tagebuch, mit Face ID gesperrt. Deine Einträge bleiben auf deinen Geräten und werden privat über iCloud \
                synchronisiert, ganz ohne Konto und ohne Werbung.
                """,
                reason: "From your English text. German reviews say “gesperrt” for the lock, so the text uses it.",
                source: "Claude Code", createdAt: now
            ),
            ProductPageTextSuggestion(
                pageID: PageID.privateDiary, locale: "ja",
                text: "Face IDでロックできる、あなただけの日記。記録はデバイスに残り、iCloudで非公開のまま同期されます。",
                reason: "From your English text, in the polite form the Japanese page already uses.",
                source: "Claude Code", createdAt: now
            ),
        ]
    }

    /// The English text Atlas stopped: "free", a discount and Android.
    static var refusedSuggestion: ProductPageTextSuggestion {
        let text = "Try Lumen Plus free for 7 days, now 50% off. Better than any diary app on Android."
        let issues = StoreTextGuidelineCheck.issues(in: text, for: ListingField.promotionalText)
        return ProductPageTextSuggestion(
            pageID: PageID.privateDiary, locale: "en-US", text: text, reason: "", source: "Claude Code",
            refusal: ProductPageTextRefusal.reason(for: issues), refusedPhrases: issues.flatMap(\.phrases), createdAt: Self.now
        )
    }

    static func archive(suggestions: Bool = true, drafts: Bool = true) -> ProductPagesArchive {
        ProductPagesArchive(
            pageSuggestions: suggestions ? pageSuggestions : [],
            textSuggestions: textSuggestions,
            drafts: drafts ? [privateDiary] : []
        )
    }

    @MainActor
    static func store(_ archive: ProductPagesArchive = archive()) -> ProductPagesStore {
        let store = ProductPagesStore()
        store.load(archive, for: appID)
        return store
    }

    // MARK: - Numbers

    /// The 28 days through Nov 9, one fact per page.
    static var analyticsArchive: EngagementArchive {
        let day = AnalyticsDay(numbersThrough)
        let numbers: [(String, Int, Int, Int)] = [
            (ProductPageNumbers.defaultPageName, 151_000, 8050, 2550), ("Prompts", 18400, 1020, 330),
            ("Mood tracking", 9200, 470, 120), ("Sleep & wind-down", 1240, 96, 34),
        ]
        var archive = EngagementArchive()
        archive.pageFacts = numbers.map { page, impressions, views, downloads in
            var fact = EngagementFact(day: day, territory: "", source: "", device: "", page: page)
            fact.impressions = impressions
            fact.pageViews = views
            fact.downloads = downloads
            return fact
        }
        return archive
    }

    @MainActor
    static func analytics() -> AnalyticsStore {
        let store = AnalyticsStore()
        store.load(appID: appID, record: AnalyticsAppRecord(askedOn: Self.now.addingTimeInterval(-30 * 86400)), archive: analyticsArchive)
        return store
    }
}
#endif
