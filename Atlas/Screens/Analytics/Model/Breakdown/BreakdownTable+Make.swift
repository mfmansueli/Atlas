//
//  BreakdownTable+Make.swift
//  Atlas
//

import Foundation

extension BreakdownTable {
    static func make(_ dataset: AnalyticsDataset, dimension: BreakdownDimension, period: AnalyticsPeriod, context: AnalyticsContext) -> BreakdownTable {
        let totals = dataset.totals(in: period)
        let averages = (view: totals.fraction(.pageViews), download: totals.fraction(.downloads), start: totals.startFraction)
        func row(id: String, name: String, region: String? = nil, detail: String? = nil, totals: FunnelTotals) -> BreakdownRow {
            BreakdownRow(
                id: id, name: name, regionCode: region, detail: detail, totals: totals,
                viewRate: totals.rate(.pageViews, average: averages.view),
                downloadRate: totals.rate(.downloads, average: averages.download),
                startRate: totals.startRate(average: averages.start)
            )
        }
        let facts = dataset.engagement.filter { period.contains($0.day) }
        var rows: [BreakdownRow] = []
        switch dimension {
        case .territory:
            for code in Set(facts.map(\.territory)) where !code.isEmpty {
                let territory = TerritoryCatalog.standard.territory(alpha2: code)
                rows.append(row(
                    id: code, name: territory?.name ?? code, region: code, detail: context.locale(for: code)?.name,
                    totals: dataset.totals(in: period, filter: FactFilter(territories: [code]))
                ))
            }
        case .language:
            let byLocale = Dictionary(grouping: Set(facts.map(\.territory)).filter { !$0.isEmpty }) { context.locale(for: $0)?.code ?? "" }
            for (code, territories) in byLocale {
                let locale = StoreLocaleCatalog.locale(code: code)
                let detail = territories.count == 1 ? String(localized: "1 territory") : String(localized: "\(territories.count) territories")
                rows.append(row(
                    id: code.isEmpty ? "other" : code, name: locale?.name ?? String(localized: "Other"), region: locale?.regionCode, detail: detail,
                    totals: dataset.totals(in: period, filter: FactFilter(territories: Set(territories)))
                ))
            }
        case .source:
            for source in Set(facts.map(\.source)) {
                var totals = dataset.totals(in: period, filter: FactFilter(source: source))
                totals.starts = nil
                totals.proceeds = nil
                rows.append(row(id: source, name: source, detail: sourceDetail(source), totals: totals))
            }
        case .device:
            for device in Set(facts.map(\.device)) where !device.isEmpty {
                rows.append(row(id: device, name: device, totals: dataset.totals(in: period, filter: FactFilter(device: device))))
            }
        case .productPage, .referrer, .campaign:
            for split in detailedSplits(dataset, dimension: dimension, period: period) {
                rows.append(row(id: split.name, name: split.name, detail: split.detail, totals: pageTotals(split.facts)))
            }
        }
        rows.sort { ($0.totals.impressions ?? 0, $1.name) > ($1.totals.impressions ?? 0, $0.name) }
        var table = BreakdownTable(dimension: dimension, period: period, totals: totals, rows: rows, footer: footer(dimension, hasSales: dataset.hasSales))
        table.addReports(dataset.reports)
        return table
    }

    /// The Detailed facts by product page, referrer or campaign, each with
    /// what's under its name: whether a page is custom, the kind of source
    /// a referrer is, the page a campaign opens.
    private static func detailedSplits(
        _ dataset: AnalyticsDataset, dimension: BreakdownDimension, period: AnalyticsPeriod
    ) -> [(name: String, detail: String?, facts: [EngagementFact])] {
        let key: (EngagementFact) -> String? = switch dimension {
        case .campaign: { $0.campaign }
        case .referrer: { $0.referrer }
        default: { $0.page.isEmpty || $0.page == "No page" ? nil : $0.page }
        }
        let detailed = dataset.pages.filter { period.contains($0.day) && key($0) != nil }
        return Dictionary(grouping: detailed) { key($0) ?? "" }.map { name, facts in
            let detail: String?
            if dimension == .productPage {
                detail = name == "Default product page" ? nil : String(localized: "Custom product page")
            } else if dimension == .campaign {
                let pages = Set(facts.map(\.page)).filter { !$0.isEmpty && $0 != "No page" }
                detail = pages.count == 1 ? pages.first : nil
            } else {
                let kinds = Set(facts.map(\.source))
                detail = kinds.count == 1 ? sourceDetail(kinds.first ?? "") : nil
            }
            return (name, detail, facts)
        }
    }

    /// A Detailed split's funnel: Apple doesn't tie sales or
    /// subscriptions to it.
    private static func pageTotals(_ facts: [EngagementFact]) -> FunnelTotals {
        FunnelTotals(
            impressions: facts.reduce(0) { $0 + $1.impressions },
            pageViews: facts.reduce(0) { $0 + $1.pageViews },
            downloads: facts.reduce(0) { $0 + $1.downloads }
        )
    }

    private static func sourceDetail(_ source: String) -> String? {
        switch source {
        case "App Store Search": String(localized: "People who saw the app in search results")
        case "App Store Browse": String(localized: "Today, categories and charts")
        case "App Referrer": String(localized: "Links from other apps")
        case "Web Referrer": String(localized: "Links from websites")
        case "Institutional": String(localized: "Apple School and Business Manager")
        case "App Clip": String(localized: "From the app’s App Clip")
        default: nil
        }
    }

    /// The table's footer. `linksSubscribers`: Apple's subscription reports
    /// name each subscriber's page, campaign and source, so the new columns
    /// link them; `hasSample`: deletions and sessions show, which count
    /// only people who share analytics.
    static func footer(_ dimension: BreakdownDimension, hasSales _: Bool, linksSubscribers: Bool = false, hasSample: Bool = false) -> String {
        var privacy = String(
            localized: "Apple hides rows under five people and adds noise, so rows may total less."
        )
        if hasSample {
            privacy = String(localized: "Deletions and sessions are a sample: only people who share analytics.", comment: "kind:description")
                + " " + privacy
        }
        if linksSubscribers {
            privacy = String(
                localized: "Trials and paid come from Apple’s subscription reports, which name each subscriber’s page, campaign and source.",
                comment: "kind:description"
            ) + " " + privacy
        }
        switch dimension {
        case .territory, .device:
            return privacy
        case .language:
            return String(localized: "A language sums the territories whose App Store shows that page.") + " " + privacy
        case .source:
            return String(localized: "Apple doesn’t split starts and proceeds by source.") + " " + privacy
        case .productPage where linksSubscribers:
            return String(localized: "Product page test results are in App Store Connect.", comment: "kind:description") + " " + privacy
        case .productPage:
            return String(
                localized: """
                Subscriptions aren’t linked to a page. Product page test results are in App Store Connect.
                """
            ) + " " + privacy
        case .referrer:
            return String(
                localized: "The app or website people came from, when Apple knows it. Subscriptions aren’t linked."
            ) + " " + privacy
        case .campaign:
            return String(
                localized: """
                People who came through a campaign link (its ct token). Make links in App Store Connect → App \
                Analytics → Campaigns.
                """
            ) + " " + privacy
        }
    }
}
