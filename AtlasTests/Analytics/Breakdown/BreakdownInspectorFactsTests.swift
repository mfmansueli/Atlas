//
//  BreakdownInspectorFactsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the inspector's facts")
struct BreakdownInspectorFactsTests {
    private static func row(_ id: String, detail: String? = nil) -> BreakdownRow {
        BreakdownRow(
            id: id, name: id, detail: detail, totals: FunnelTotals(impressions: 1000, pageViews: 100, downloads: 30),
            viewRate: .missing, downloadRate: .missing, startRate: .missing
        )
    }

    private static var context: AnalyticsContext {
        var context = AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: ["en-US", "de-DE"].compactMap(StoreLocaleCatalog.locale(code:))
        )
        context.screenshotCoverage = ScreenshotCoverage(localesByDevice: [.iPhone: ["en-US", "de-DE"], .iPad: ["en-US"]], pageLocaleCount: 2)
        return context
    }

    @Test func searchSaysWhatItIsAndWhatPeopleSee() {
        let facts = BreakdownInspectorFacts.extra(
            for: Self.row(BreakdownInspectorFacts.search, detail: "People who saw the app in search results"), dimension: .source,
            context: Self.context
        )
        #expect(facts.count == 2)
        #expect(facts.first?.value == "People who saw the app in search results")
        #expect(facts.last?.value.contains("first three screenshots") == true)
    }

    @Test func aSourceWithoutADetailOrViewHasNoFacts() {
        #expect(BreakdownInspectorFacts.extra(for: Self.row("Unavailable"), dimension: .source, context: Self.context).isEmpty)
    }

    @Test func aDeviceSaysItsSetsLanguages() {
        let iPad = BreakdownInspectorFacts.extra(for: Self.row("iPad"), dimension: .device, context: Self.context)
        #expect(iPad.count == 1)
        #expect(iPad.first?.isWarning == true)
        let iPhone = BreakdownInspectorFacts.extra(for: Self.row("iPhone"), dimension: .device, context: Self.context)
        #expect(iPhone.first?.isWarning == false)
    }

    @Test func noFactsBeforeTheSetsAreRead() {
        let context = AnalyticsContext()
        #expect(BreakdownInspectorFacts.extra(for: Self.row("iPad"), dimension: .device, context: context).isEmpty)
        #expect(BreakdownInspectorFacts.extra(for: Self.row("DE"), dimension: .territory, context: context).isEmpty)
    }

    @Test func aDeviceActionOpensThatDevicesScreenshots() {
        let action = FindingAction.screenshotsOnDevice(.iPad, locale: "en-US")
        #expect(action.area == .screenshots)
        #expect(action.title.contains(ScreenshotDisplayType.iPad.title))
        #expect(!action.isInsideAnalytics)
    }
}
