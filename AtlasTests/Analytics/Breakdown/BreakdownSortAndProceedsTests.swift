//
//  BreakdownSortAndProceedsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 92's Break It Down: what VoiceOver says for a sorted column, and
/// the banner the Overview's Proceeds number opens it with.
@MainActor
@Suite("Analytics · Break It Down sorting and proceeds")
struct BreakdownSortAndProceedsTests {
    private typealias AppIDs = DebugFixtures.AppID

    private func model() -> AnalyticsViewModel {
        let model = AnalyticsViewModel(app: DebugFixtures.lumen, store: DebugAnalyticsData.store(), services: DebugAnalyticsServices())
        model.configure(sellsSubscriptions: true, changes: ChangeLog.changes(for: AppIDs.lumen, in: DebugAnalyticsData.pushRecords))
        model.setContext(DebugAnalyticsData.context)
        return model
    }

    // MARK: - Sorting

    @Test func aSortedHeaderSaysWhichWay() {
        #expect(BreakdownSortLabel.label(title: "Impressions", isSorted: false, ascending: false) == "Impressions")
        #expect(BreakdownSortLabel.label(title: "Impressions", isSorted: true, ascending: false) == "Impressions, sorted descending")
        #expect(BreakdownSortLabel.label(title: "Impressions", isSorted: true, ascending: true) == "Impressions, sorted ascending")
        #expect(BreakdownSortLabel.hint(title: "Impressions", isSorted: false, ascending: false) == "Sorts by Impressions.")
        #expect(BreakdownSortLabel.hint(title: "Impressions", isSorted: true, ascending: false) == "Sorts ascending.")
        #expect(BreakdownSortLabel.systemImage(ascending: false) == "chevron.down")
    }

    @Test func clickingAColumnSortsDescendingThenAscending() {
        let model = model()
        model.tab = .breakDown
        model.sort(by: .downloads)
        #expect(model.sortColumn == .downloads)
        #expect(!model.sortAscending)
        let descending = model.sortedRows.compactMap(\.totals.downloads)
        #expect(descending == descending.sorted(by: >))
        model.sort(by: .downloads)
        #expect(model.sortAscending)
        let ascending = model.sortedRows.compactMap(\.totals.downloads)
        #expect(ascending == ascending.sorted())
        // The name sorts A to Z first.
        model.sort(by: .name)
        #expect(model.sortAscending)
    }

    @Test func aRowOpensTheInspectorAndClosesItAgain() {
        let model = model()
        model.toggleRow("DE")
        #expect(model.selectedRow?.name == "Germany")
        model.toggleRow("DE")
        #expect(model.selectedRow == nil)
    }

    // MARK: - From the Proceeds number

    @Test func theProceedsNumberOpensTerritoriesByProceedsWithTheBanner() throws {
        let model = model()
        model.dimension = .source
        model.showProceedsByCountry()
        #expect(model.tab == .breakDown)
        #expect(model.dimension == .territory)
        #expect(model.sortColumn == .proceeds)
        #expect(!model.sortAscending)
        let text = try #require(model.proceedsBannerText)
        let total = try #require(model.table?.totals.proceeds)
        #expect(text.contains(AnalyticsText.dollars(total)))
        #expect(model.highlightedColumn == .proceeds)
        #expect(BreakdownProceedsText.whereToLook == "The Proceeds column is on the right; the total is in the All territories row.")
    }

    @Test func closingTheBannerOrPickingAnotherSplitClearsIt() {
        let model = model()
        model.showProceedsByCountry()
        model.closeProceedsBanner()
        #expect(!model.showsProceedsBanner)
        #expect(model.proceedsBannerText == nil)
        #expect(model.highlightedColumn == nil)

        model.showProceedsByCountry()
        model.choose(.language)
        #expect(model.dimension == .language)
        #expect(!model.showsProceedsBanner)
        #expect(model.highlightedColumn == nil)
    }

    @Test func theBannerNamesTheTotalAndTheTerritoriesThatBroughtTheMost() throws {
        let period = AnalyticsPeriod(ending: AnalyticsDay(number: 1000), length: 28)
        func row(_ id: String, _ name: String, _ proceeds: Decimal?) -> BreakdownRow {
            var totals = FunnelTotals()
            totals.proceeds = proceeds
            return BreakdownRow(id: id, name: name, totals: totals, viewRate: .missing, downloadRate: .missing, startRate: .missing)
        }
        var totals = FunnelTotals()
        totals.proceeds = 1000
        let table = BreakdownTable(
            dimension: .territory, period: period, totals: totals,
            rows: [row("FR", "France", 100), row("DE", "Germany", 600), row("JP", "Japan", 100), row("KR", "South Korea", nil)],
            footer: ""
        )
        let text = try #require(BreakdownProceedsText.explanation(table))
        #expect(text.contains(AnalyticsText.dollars(1000)))
        #expect(text.contains("28"))
        #expect(text.contains("Germany brought \(AnalyticsText.dollars(600)) (\(AnalyticsText.wholePercent(0.6)))"))
        #expect(text.contains("each."), "France and Japan brought the same")
        #expect(!text.contains("South Korea"))

        var other = table
        other.dimension = .language
        #expect(BreakdownProceedsText.explanation(other) == nil, "only territories")
        var none = table
        none.totals.proceeds = nil
        #expect(BreakdownProceedsText.explanation(none) == nil)
    }
}
#endif
