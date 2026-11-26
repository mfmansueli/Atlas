//
//  AnalyticsTabSummaryTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("Analytics · the strip's card summaries")
struct AnalyticsTabSummaryTests {
    private typealias Inputs = AnalyticsTabSummary.Inputs

    @Test func aViewWithoutDataSaysItsCase() {
        let summary = AnalyticsTabSummary.make(.subscriptions, availability: .noSubscriptionsSold, inputs: Inputs(activeSubscribers: 10))
        #expect(summary.text == "None sold yet")
        #expect(summary.tone == .neutral)
    }

    @Test func whatToTryAndAfterChangesCount() {
        #expect(AnalyticsTabSummary.make(.whatToTry, inputs: Inputs(newFindings: 3, openFindings: 5)).text == "3 new to try")
        #expect(AnalyticsTabSummary.make(.whatToTry, inputs: Inputs(openFindings: 5)).text == "5 to try")
        #expect(AnalyticsTabSummary.make(.whatToTry, inputs: Inputs()).text == "Nothing yet")
        #expect(AnalyticsTabSummary.make(.afterChanges, inputs: Inputs(pushes: 5, betterPushes: 1)).text == "5 pushes · 1 better")
        #expect(AnalyticsTabSummary.make(.afterChanges, inputs: Inputs(pushes: 1)).text == "1 push")
        #expect(AnalyticsTabSummary.make(.afterChanges, inputs: Inputs()).text == "No pushes yet")
        #expect(AnalyticsTabSummary.make(.breakDown, inputs: Inputs()).text == "Country, language, source…")
    }

    @Test func subscriptionsAndStability() {
        #expect(AnalyticsTabSummary.make(.subscriptions, inputs: Inputs(activeSubscribers: 1284)).text == "\(AnalyticsText.count(1284)) subscribers")
        #expect(AnalyticsTabSummary.make(.subscriptions, inputs: Inputs(activeSubscribers: 1)).text == "1 subscriber")
        let period = AnalyticsPeriod(ending: AnalyticsDay(number: 20400), length: 28)
        let worse = StabilityReport(
            period: period, latest: .init(version: "1.4", crashes: 64, sessions: 1000, devices: 10),
            previous: .init(version: "1.3", crashes: 20, sessions: 1000, devices: 10), comparison: .higher(.sure), devices: [], days: []
        )
        let summary = AnalyticsTabSummary.make(.stability, inputs: Inputs(stability: worse))
        #expect(summary.text == "Crashes \(AnalyticsText.times(3.2)) on 1.4")
        #expect(summary.tone == .warning)
        #expect(AnalyticsTabSummary.make(.stability, inputs: Inputs()).text == "No crashes reported")
    }

    @Test func fewerNamesTheStep() {
        #expect(AnalyticsTabSummary.fewer(.pageViews) == "Fewer page views")
        #expect(AnalyticsTabSummary.fewer(.paid) == "Fewer paid starts")
    }
}
