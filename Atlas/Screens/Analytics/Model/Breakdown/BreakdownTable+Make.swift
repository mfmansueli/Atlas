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
        case .productPage:
            let pages = Dictionary(grouping: dataset.pages.filter { period.contains($0.day) }, by: \.page)
            for (page, facts) in pages where !page.isEmpty && page != "No page" {
                let totals = FunnelTotals(
                    impressions: facts.reduce(0) { $0 + $1.impressions },
                    pageViews: facts.reduce(0) { $0 + $1.pageViews },
                    downloads: facts.reduce(0) { $0 + $1.downloads }
                )
                let detail = page == "Default product page" ? nil : String(localized: "Custom product page")
                rows.append(row(id: page, name: page, detail: detail, totals: totals))
            }
        }
        rows.sort { ($0.totals.impressions ?? 0, $1.name) > ($1.totals.impressions ?? 0, $0.name) }
        return BreakdownTable(dimension: dimension, period: period, totals: totals, rows: rows, footer: footer(dimension, hasSales: dataset.hasSales))
    }

    private static func sourceDetail(_ source: String) -> String? {
        switch source {
        case "App Store Search": String(localized: "People who searched and saw the app in the results")
        case "App Store Browse": String(localized: "Today, categories and charts")
        case "App Referrer": String(localized: "Links from other apps")
        case "Web Referrer": String(localized: "Links from websites")
        case "Institutional": String(localized: "Apple School and Business Manager")
        case "App Clip": String(localized: "From the app’s App Clip")
        default: nil
        }
    }

    private static func footer(_ dimension: BreakdownDimension, hasSales _: Bool) -> String {
        let privacy = String(
            localized: "Apple leaves out rows with fewer than five people and adds a little noise, so rows can add up to less than the total."
        )
        switch dimension {
        case .territory, .device:
            return privacy
        case .language:
            return String(localized: "Apple reports by territory. A language adds up the territories whose App Store shows that page.") + " " + privacy
        case .source:
            return String(localized: "Apple doesn’t link subscriptions to a source, so starts and proceeds aren’t split here.") + " " + privacy
        case .productPage:
            return String(
                localized: """
                From Apple’s detailed reports. Subscriptions aren’t linked to a page, and Apple’s result for a product page test \
                isn’t in its reports: see it in App Store Connect.
                """
            ) + " " + privacy
        }
    }
}
