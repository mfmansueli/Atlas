//
//  FindingRulesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · findings")
struct FindingRulesTests {
    private typealias Data = AnalyticsTestData

    private var dataset: AnalyticsDataset {
        var dataset = Data.lumen
        dataset.engagement = [
            Data.fact(territory: "US", impressions: 150_000, views: 8300, downloads: 2850),
            Data.fact(territory: "DE", impressions: 24800, views: 1480, downloads: 260),
            Data.fact(back: 28, territory: "US", impressions: 150_000, views: 9200, downloads: 3050),
            Data.fact(back: 28, territory: "DE", impressions: 24800, views: 1480, downloads: 260),
            Data.fact(back: 60, impressions: 1),
        ]
        dataset.events = [
            Data.event(.paidFromTrial, 146, periods: 1), Data.event(.cancellation, 189, periods: 0, reason: "Canceled"),
            Data.event(.paidFromTrial, 5, territory: "BR", periods: 1), Data.event(.cancellation, 31, territory: "BR", periods: 0, reason: "Canceled"),
            Data.event(.cancellation, 16, periods: 3, reason: "Canceled"), Data.event(.trialStart, 400), Data.event(.trialStart, 400, back: 28),
        ]
        return dataset
    }

    private var context: AnalyticsContext {
        AnalyticsContext(
            primaryLocale: StoreLocaleCatalog.locale(code: "en-US"),
            pageLocales: ["en-US", "de-DE", "pt-BR"].compactMap(StoreLocaleCatalog.locale(code:)),
            machineTranslated: ["de-DE"],
            screenshotLocales: ["en-US", "pt-BR"],
            prices: ["BR": TerritoryPriceContext(priceText: "R$ 249,90", suggestedText: "R$ 104,90", ratio: 2.4, productName: "Annual")],
            liveRetentionMessages: 0
        )
    }

    @Test func aStepThatFellIsAFinding() throws {
        let findings = FindingRules.findings(dataset, context: context)
        let step = try #require(findings.first { $0.id == "step.pageViews" })
        #expect(step.source == .builtIn)
        #expect(step.area == .screenshots)
        #expect(step.action == .screenshots(locale: nil))
        #expect(step.numbers.map(\.label) == ["Last 28 days", "28 days before", "Difference"])
        #expect(step.sureness == "Sure")
    }

    @Test func aTerritoryThatDownloadsLessNamesWhatItsPageLooksLike() throws {
        let findings = FindingRules.findings(dataset, context: context)
        let germany = try #require(findings.first { $0.id == "territory.downloads.DE" })
        #expect(germany.title == "Germany downloads less often than Lumen Journal’s average.")
        #expect(germany.why.contains("machine-translated"))
        #expect(germany.why.contains("another language’s screenshots"))
        #expect(germany.action == .storePage(locale: "de-DE"))
        #expect(germany.secondAction == .screenshots(locale: "de-DE"))
        #expect(germany.action.title == "Open Store Page in German")
        #expect(!findings.contains { $0.id == "territory.downloads.US" })
    }

    @Test func trialsThatDontConvertWhereThePriceIsHighPointToPricing() throws {
        let findings = FindingRules.findings(dataset, context: context)
        let brazil = try #require(findings.first { $0.id == "territory.paid.BR" })
        #expect(brazil.area == .pricing)
        #expect(brazil.action == .pricing(territory: "BR"))
        #expect(brazil.why.hasPrefix("The Annual price there is 2"))
        #expect(brazil.why.hasSuffix("× the purchasing-power price."))
        #expect(brazil.numbers.first?.value == "5 of 36")
        // Without a price to blame, it isn't said.
        var noPrices = context
        noPrices.prices = [:]
        #expect(!FindingRules.findings(dataset, context: noPrices).contains { $0.id == "territory.paid.BR" })
    }

    @Test func earlyCancellationsWithoutARetentionMessagePointToRetention() throws {
        let findings = FindingRules.findings(dataset, context: context)
        let early = try #require(findings.first { $0.id == "retention.early" })
        #expect(early.action == .retention)
        #expect(early.title.contains("before first renewal"))
        var live = context
        live.liveRetentionMessages = 1
        #expect(!FindingRules.findings(dataset, context: live).contains { $0.id == "retention.early" })
        live.liveRetentionMessages = nil
        #expect(!FindingRules.findings(dataset, context: live).contains { $0.id == "retention.early" })
    }

    @Test func lessThanTwentyEightDaysHasNoFindings() {
        var dataset = dataset
        dataset.engagement = [Data.fact(impressions: 3100, views: 240, downloads: 61), Data.fact(back: 8, impressions: 10)]
        dataset.events = []
        #expect(FindingRules.findings(dataset, context: context).isEmpty)
    }

    // MARK: - State

    private func finding(_ id: String, signal: Double? = nil, source: FindingSource = .builtIn) -> AnalyticsFinding {
        AnalyticsFinding(id: id, source: source, title: id, why: "", sureness: "Sure", surenessDetail: "", action: .retention, signal: signal)
    }

    @Test func findingsAreNewUntilSeenAndKeepTheirFirstDate() {
        var state = AnalyticsFindingsState()
        let first = Date(timeIntervalSince1970: 1000)
        var one = finding("a")
        one.date = first
        state.update(builtIn: [one])
        #expect(state.newCount == 1)
        state.seen = ["a"]
        var again = finding("a")
        again.date = Date(timeIntervalSince1970: 9000)
        state.update(builtIn: [again, finding("b")])
        #expect(state.builtIn.first?.date == first)
        #expect(state.newCount == 1)
        #expect(state.isNew(finding("b")))
    }

    @Test func aDismissedFindingComesBackOnlyWhenItsNumberChangesALot() {
        var state = AnalyticsFindingsState()
        state.update(builtIn: [finding("a", signal: 0.20)])
        state.seen = ["a"]
        state.dismissed = [DismissedFinding(finding: finding("a", signal: 0.20), date: .now)]
        state.update(builtIn: [finding("a", signal: 0.22)])
        #expect(state.open.isEmpty)
        state.update(builtIn: [finding("a", signal: 0.12)])
        #expect(state.open.map(\.id) == ["a"])
        #expect(state.newCount == 1)
    }

    @Test func assistantsFindingsComeFirst() {
        var state = AnalyticsFindingsState()
        state.update(builtIn: [finding("a")])
        state.fromAssistants = [finding("cc", source: .assistant("Claude Code"))]
        #expect(state.open.map(\.id) == ["cc", "a"])
        #expect(FindingSource.assistant("Claude Code").mark == "CC")
        #expect(FindingSource.builtIn.mark == "AL")
    }
}
