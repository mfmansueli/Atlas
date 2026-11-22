//
//  DebugAnalyticsData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Canned Analytics for the sample apps, shaped like the design's boards:
/// Lumen Journal with 180 days and a drop in tap-through after new
/// screenshots on Oct 21, Tempo without a subscription, Parcel Pal with 9
/// days, Quiet Timer with almost no traffic. "Today" is Nov 11, 2026 and
/// the data runs through Nov 9.
enum DebugAnalyticsData {
    typealias AppIDs = DebugFixtures.AppID

    static let today = date(month: 11, day: 11)
    static let through = AnalyticsDay(date(month: 11, day: 9))

    static func date(month: Int, day: Int, hour: Int = 12) -> Date {
        Calendar.gmtGregorian.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .now
    }

    /// Code, impressions, page views, downloads, trial starts, proceeds
    /// over 28 days, and trial → paid.
    private static let territories: [DebugAnalyticsTerritory] = [
        DebugAnalyticsTerritory("US", 61200, 3610, 1190, 172, 2480, 0.43),
        DebugAnalyticsTerritory("DE", 24800, 1480, 260, 33, 430, 0.42),
        DebugAnalyticsTerritory("GB", 14100, 820, 268, 36, 430, 0.42),
        DebugAnalyticsTerritory("JP", 12900, 610, 205, 28, 390, 0.42),
        DebugAnalyticsTerritory("FR", 9800, 540, 170, 19, 220, 0.39),
        DebugAnalyticsTerritory("BR", 9200, 560, 214, 30, 96, 0.14),
        DebugAnalyticsTerritory("CA", 7400, 430, 140, 20, 260, 0.44),
        DebugAnalyticsTerritory("IT", 6100, 330, 104, 11, 130, 0.40),
        DebugAnalyticsTerritory("ES", 5900, 300, 98, 9, 105, 0.40),
        DebugAnalyticsTerritory("KR", 4300, 190, 61, 6, 70, 0.40),
        DebugAnalyticsTerritory("MX", 3900, 220, 81, 7, 40, 0.30),
        DebugAnalyticsTerritory("IN", 3600, 260, 120, 5, 18, 0.20),
        DebugAnalyticsTerritory("NL", 2400, 140, 46, 4, 52, 0.40),
        DebugAnalyticsTerritory("PL", 1900, 96, 31, 1, 12, 0.30),
        DebugAnalyticsTerritory("TR", 1100, 40, 12, 0, 0, 0.30),
    ]

    /// Name, share of impressions, page views per impression against the average.
    private static let sources: [(String, Double, Double)] = [
        ("App Store Search", 0.80, 0.39), ("App Store Browse", 0.114, 1.68), ("App Referrer", 0.053, 5.0),
        ("Web Referrer", 0.027, 8.0), ("Institutional", 0.006, 2.2),
    ]

    private static let devices: [(String, Double)] = [("iPhone", 0.86), ("iPad", 0.115), ("Desktop", 0.025)]

    /// Lumen Journal: 180 days ending Nov 9.
    static var lumenArchive: EngagementArchive {
        var random = DebugAnalyticsRandom(seed: 7)
        var facts: [EngagementFact] = []
        for back in 0..<180 {
            let day = through.adding(-back)
            // Impressions grew a month ago; tap-through fell with the new
            // screenshots 20 days back, and downloads per view rose a little.
            let volume = back < 30 ? 1.05 : 0.97
            let tap = back < 20 ? 0.8 : 1.0
            let download = back < 20 ? 1.03 : 1.0
            for territory in territories {
                let (code, impressions, views, downloads) = (territory.code, territory.impressions, territory.views, territory.downloads)
                for (source, share, lift) in sources {
                    for (device, deviceShare) in devices {
                        let shown = impressions / 28 * volume * share * deviceShare
                        let viewRate = views / impressions * lift * tap
                        var fact = EngagementFact(day: day, territory: code, source: source, device: device)
                        fact.impressions = random.count(shown * (0.85 + random.next() * 0.3))
                        fact.pageViews = random.count(shown * viewRate)
                        fact.downloads = random.count(shown * viewRate * downloads / views * download)
                        if fact.impressions + fact.pageViews + fact.downloads > 0 { facts.append(fact) }
                    }
                }
            }
        }
        var pages: [EngagementFact] = []
        for back in 0..<180 {
            for (page, share) in [("Default product page", 0.85), ("Prompts", 0.10), ("Mood tracking", 0.05)] {
                var fact = EngagementFact(day: through.adding(-back), territory: "", source: "", device: "", page: page)
                fact.impressions = random.count(6500 * share)
                fact.pageViews = random.count(350 * share)
                fact.downloads = random.count(111 * share * (page == "Mood tracking" ? 0.8 : 1))
                pages.append(fact)
            }
            // Where the Prompts page's link is used: a campaign and two sites.
            for (referrer, campaign, views) in [("instagram.com", "spring_ig", 14.0), ("reddit.com", nil, 6.0), ("Notion", "notion_tpl", 4.0)] {
                var fact = EngagementFact(
                    day: through.adding(-back), territory: "", source: referrer == "Notion" ? "App Referrer" : "Web Referrer", device: "",
                    page: "Prompts", referrer: referrer, campaign: campaign
                )
                fact.pageViews = random.count(views)
                fact.downloads = random.count(views * 0.3)
                pages.append(fact)
            }
        }
        return EngagementArchive(facts: EngagementFact.merged(facts), pageFacts: pages)
    }

    /// A small app's archive from daily averages.
    static func archive(days: Int, impressions: Double, views: Double, downloads: Double, seed: UInt64) -> EngagementArchive {
        var random = DebugAnalyticsRandom(seed: seed)
        var facts: [EngagementFact] = []
        for back in 0..<days {
            for (code, share) in [("US", 0.6), ("GB", 0.25), ("DE", 0.15)] {
                var fact = EngagementFact(day: through.adding(-back), territory: code, source: "App Store Search", device: "iPhone")
                fact.impressions = random.count(impressions * share)
                fact.pageViews = random.count(views * share)
                fact.downloads = random.count(downloads * share)
                if fact.impressions + fact.pageViews + fact.downloads > 0 { facts.append(fact) }
            }
        }
        return EngagementArchive(facts: facts)
    }

    /// Every sample app's sales, as the vendor's reports would bring them.
    static var sales: SalesArchive {
        var random = DebugAnalyticsRandom(seed: 11)
        var archive = SalesArchive()
        for back in 0..<180 {
            let day = through.adding(-back)
            archive.days.insert(day.number)
            for territory in territories {
                let (code, trials, proceeds, paidRate) = (territory.code, territory.trials, territory.proceeds, territory.paidRate)
                let started = random.count(trials / 28 * (back < 7 ? 1.06 : 1))
                for (name, share) in [("Lumen Plus Annual", 0.62), ("Lumen Plus Monthly", 0.38)] {
                    let trialCount = random.count(Double(started) * share)
                    let paid = random.count(trials / 28 * share * paidRate)
                    let lapsed = random.count(trials / 28 * share * (1 - paidRate))
                    func event(_ kind: SubscriptionEventKind, _ quantity: Int, periods: Int = 0, reason: String = "") {
                        guard quantity > 0 else { return }
                        archive.events.append(SubscriptionEventFact(
                            day: day, appID: AppIDs.lumen, kind: kind, subscription: name, territory: code, device: "iPhone",
                            offerType: kind == .trialStart ? "Free Trial" : "", paidPeriods: periods, reason: reason, quantity: quantity
                        ))
                    }
                    event(.trialStart, trialCount)
                    event(.paidFromTrial, paid, periods: 1)
                    event(.cancellation, lapsed, reason: "Canceled")
                    // Renewals and the cancellations that came instead.
                    let weight = trials / 172 * share
                    event(.renewal, random.count(7.6 * weight), periods: 2)
                    event(.cancellation, random.count(3.1 * weight), periods: 1, reason: random.next() < 0.75 ? "Canceled" : "Billing Issue")
                    event(.renewal, random.count(6.7 * weight), periods: 3)
                    event(.cancellation, random.count(1.3 * weight), periods: 2, reason: "Canceled")
                    event(.renewal, random.count(18.3 * weight), periods: 5)
                    event(.cancellation, random.count(1.8 * weight), periods: 4, reason: random.next() < 0.6 ? "Canceled" : "Other")
                    let charges = random.count(46.8 * weight)
                    if charges > 0 {
                        archive.subscribers.append(SubscriberFact(
                            day: day, appID: AppIDs.lumen, subscription: name, territory: code, device: "iPhone", charges: charges,
                            refunds: random.next() < 0.02 ? 1 : 0, proceeds: Decimal(proceeds / 28 * share * (0.8 + random.next() * 0.4) * 1.9)
                        ))
                    }
                }
            }
        }
        for (back, scale) in [(0, 1.0), (7, 0.99), (28, 0.97), (90, 0.9)] {
            let day = through.adding(-back)
            archive.activeDays.insert(day.number)
            for territory in territories {
                let (code, trials) = (territory.code, territory.trials)
                archive.active.append(ActiveSubscriptionsFact(
                    day: day, appID: AppIDs.lumen, subscription: "Lumen Plus Annual", territory: code, paid: Int(742 * trials / 381 * scale), trials: 0
                ))
                archive.active.append(ActiveSubscriptionsFact(
                    day: day, appID: AppIDs.lumen, subscription: "Lumen Plus Monthly", territory: code, paid: Int(520 * trials / 381 * scale),
                    trials: Int(22 * trials / 381)
                ))
            }
        }
        // Parcel Pal and Quiet Timer: a handful of trials.
        for (appID, name, trials, paid) in [(AppIDs.parcel, "Parcel Plus", 4, 1), (AppIDs.quiet, "Quiet Pro", 1, 0)] {
            archive.events.append(SubscriptionEventFact(
                day: through.adding(-3), appID: appID, kind: .trialStart, subscription: name, territory: "US", offerType: "Free Trial", quantity: trials
            ))
            if paid > 0 {
                archive.events.append(SubscriptionEventFact(
                    day: through.adding(-1), appID: appID, kind: .paidFromTrial, subscription: name, territory: "US", paidPeriods: 1, quantity: paid
                ))
            }
        }
        return archive
    }

    /// What the other sections know about Lumen: German, Italian, Spanish,
    /// Korean and Dutch are machine-translated, German and Dutch use the
    /// English screenshots, and Brazil's price is 2.4× purchasing power.
    static var context: AnalyticsContext {
        let codes = ["en-US", "en-GB", "de-DE", "ja", "fr-FR", "es-ES", "pt-BR", "it", "ko", "nl-NL"]
        let locales = codes.compactMap(StoreLocaleCatalog.locale(code:))
        return AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: locales,
            machineTranslated: ["de-DE", "it", "es-ES", "ko", "nl-NL"],
            screenshotLocales: Set(codes).subtracting(["de-DE", "nl-NL"]),
            prices: [
                "BR": TerritoryPriceContext(priceText: "R$ 249,90", suggestedText: "R$ 104,90", ratio: 2.4, productName: "Annual"),
                "IN": TerritoryPriceContext(priceText: "₹ 2,999", suggestedText: "₹ 1,149", ratio: 2.6, productName: "Annual"),
                "MX": TerritoryPriceContext(priceText: "$ 699", suggestedText: "$ 369", ratio: 1.9, productName: "Annual"),
                "US": TerritoryPriceContext(priceText: "$39.99", suggestedText: "$39.99", ratio: 1, productName: "Annual"),
                "DE": TerritoryPriceContext(priceText: "39,99 €", suggestedText: "41,99 €", ratio: 0.95, productName: "Annual"),
            ],
            liveRetentionMessages: 0
        )
    }

    /// What Lumen pushed, for the timeline's marks and After Changes.
    static var pushRecords: [PushRecord] {
        func listing(_ field: String, locale: String, region: String, old: String, new: String) -> PendingChange {
            PendingChange(
                id: "storePage.\(AppIDs.lumen).version.v1.\(locale).\(field.lowercased())", appID: AppIDs.lumen, section: .storePage,
                group: "Store Page · Version 3.1", title: "\(StoreLocaleCatalog.locale(code: locale)?.name ?? locale) · \(field)", flagRegion: region,
                oldValue: old, newValue: new, requests: []
            )
        }
        let paywall = PendingChange(
            id: "storePage.\(AppIDs.lumen).inApp.annual.en-US.name", appID: AppIDs.lumen, section: .storePage, group: "Store Page · In-App Texts",
            title: "English (U.S.) · Annual · Name", flagRegion: "US", oldValue: "Annual", newValue: "Lumen Plus, yearly", requests: []
        )
        let prices = ["BR", "IN", "MX"].map { region in
            PendingChange(
                id: "pricing.\(AppIDs.lumen).annual.\(region)", appID: AppIDs.lumen, section: .subscriptionPricing,
                group: "Subscription Pricing · Annual", title: TerritoryCatalog.standard.territory(alpha2: region)?.name ?? region, flagRegion: region,
                oldValue: "", newValue: "", requests: []
            )
        }
        func record(_ month: Int, _ day: Int, _ title: String, _ changes: [PendingChange], screenshots: ScreenshotPushSummary? = nil) -> PushRecord {
            PushRecord(
                date: date(month: month, day: day, hour: 15), appID: AppIDs.lumen, appName: "Lumen Journal", title: title, pushed: changes,
                screenshots: screenshots
            )
        }
        return [
            record(11, 3, "Store Page · In-App Texts", [paywall]),
            record(10, 26, "Subscription Pricing · 3 territories", prices),
            record(10, 21, "Screenshots · 10 images in 2 locales", [], screenshots: ScreenshotPushSummary(
                pushedCount: 10, failures: [], locales: ["en-US", "en-GB"], keptLocales: [], backupID: nil, isRestore: false
            )),
            record(10, 2, "Store Page · 1 text in 1 locale", [
                listing("Subtitle", locale: "en-US", region: "US", old: "Mood journal", new: "Mood journal & prompts"),
            ]),
            record(9, 8, "Store Page · 1 text in 1 locale", [
                listing("Keywords", locale: "ko", region: "KR", old: "일기,기분", new: "일기,기분,감사,저널"),
            ]),
        ]
    }

    /// Claude Code's finding about search, as `add_finding` would leave it.
    static var assistantFinding: AnalyticsFinding {
        AnalyticsFinding(
            id: "assistant.search-tap-through", source: .assistant("Claude Code"),
            title: "Search brings 80% of impressions, but only 2.1% tap through to the page.",
            why: """
            In search results people see the first three screenshots and nothing else, so those three carry the decision. \
            Tap-through fell after the new screenshots on Oct 21.
            """,
            numbers: [
                FindingNumber(label: "Share of impressions", value: "80%"),
                FindingNumber(label: "Tap-through from search", value: "2.1%", note: "Lumen 5.4% overall"),
                FindingNumber(label: "Before and after Oct 21", value: "2.4% → 1.9%"),
            ],
            sureness: "Fairly sure",
            surenessDetail: "3,094 page views from 147,360 search impressions. The drop after Oct 21 is 20 days old; the full 28 days end Nov 18.",
            action: .screenshots(locale: "en-US"), date: date(month: 11, day: 10)
        )
    }

    /// A store with the sample apps as the design's boards have them:
    /// Lumen, Tempo, Parcel Pal and Quiet Timer ready, Habitat waiting
    /// since Nov 10, Fieldnote off.
    @MainActor
    static func store(vendorNumber: String = "85012345", keyCannotReadSales: Bool = false, hasSales: Bool = true) -> AnalyticsStore {
        let store = AnalyticsStore()
        store.now = { today }
        let asked = AnalyticsAppRecord(askedOn: date(month: 5, day: 10), lastChecked: today, announcedArrival: true)
        var findings = AnalyticsFindingsState()
        findings.fromAssistants = [assistantFinding]
        store.load(
            appID: AppIDs.lumen, record: asked, archive: lumenArchive, findings: findings, reports: DebugReportsData.lumen,
            gracePeriod: DebugReportsData.lumenGracePeriod
        )
        store.load(
            appID: AppIDs.tempo, record: asked, archive: archive(days: 120, impressions: 800, views: 57.5, downloads: 7.6, seed: 3),
            reports: DebugReportsData.tempo
        )
        store.load(
            appID: AppIDs.parcel, record: AnalyticsAppRecord(askedOn: date(month: 10, day: 30), lastChecked: today, announcedArrival: true),
            archive: archive(days: 9, impressions: 344, views: 26.6, downloads: 6.8, seed: 5), reports: DebugReportsData.parcel
        )
        store.load(
            appID: AppIDs.quiet, record: asked, archive: archive(days: 120, impressions: 13.6, views: 0.75, downloads: 0.14, seed: 9),
            reports: DebugReportsData.quiet
        )
        store.load(appID: AppIDs.habitat, record: AnalyticsAppRecord(askedOn: date(month: 11, day: 10), lastChecked: today))
        store.load(sales: hasSales ? sales : SalesArchive(), vendorNumber: vendorNumber, keyCannotReadSales: keyCannotReadSales)
        return store
    }
}
#endif
