//
//  SubscriptionsReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · subscriptions")
struct SubscriptionsReportTests {
    private typealias Data = AnalyticsTestData

    private var dataset: AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID,
            appName: "Lumen Journal",
            engagement: [Data.fact(impressions: 1000, views: 100, downloads: 50), Data.fact(back: 60, impressions: 1)],
            events: [
                Data.event(.paidFromTrial, 61, periods: 1), Data.event(.cancellation, 80, periods: 0, reason: "Canceled"),
                Data.event(.paidFromTrial, 5, territory: "BR", periods: 1), Data.event(.cancellation, 31, territory: "BR", periods: 0, reason: "Canceled"),
                Data.event(.renewal, 64, periods: 2), Data.event(.cancellation, 46, periods: 1, reason: "Billing Issue"),
                Data.event(.renewal, 31, periods: 7), Data.event(.cancellation, 7, periods: 5, reason: "Price Increase Consent"),
                Data.event(.paidFromTrial, 70, back: 28, periods: 1), Data.event(.cancellation, 70, back: 28, periods: 0),
            ],
            subscribers: [
                SubscriberFact(day: Data.through, appID: Data.appID, subscription: "Annual", territory: "US", charges: 200, refunds: 3, proceeds: 4920),
                SubscriberFact(day: Data.through.adding(-28), appID: Data.appID, subscription: "Annual", territory: "US", charges: 190, proceeds: 4600),
            ],
            active: [
                ActiveSubscriptionsFact(day: Data.through, appID: Data.appID, subscription: "Annual", territory: "US", paid: 1200, trials: 84),
                ActiveSubscriptionsFact(day: Data.through.adding(-28), appID: Data.appID, subscription: "Annual", territory: "US", paid: 1180, trials: 66),
            ]
        )
    }

    private var period: AnalyticsPeriod { AnalyticsPeriod(ending: Data.through, length: 28) }

    @Test func theCardsAddUp() throws {
        let report = try #require(SubscriptionsReport.make(dataset, period: period))
        #expect(report.active == 1284)
        #expect(report.activeChange == "+3%")
        // 66 paid of 177 trials that ended.
        #expect(report.trialToPaid.measured?.count == 66)
        #expect(report.trialToPaid.measured?.total == 177)
        #expect(report.trialToPaidComparison?.outcome == .lower(.fairlySure))
        #expect(report.proceeds == 4920)
        #expect(report.proceedsChange == "+7%")
        #expect(report.refunds == 3)
        #expect(report.charges == 200)
    }

    @Test func renewalsAreCountedByWhichRenewalItWas() throws {
        let report = try #require(SubscriptionsReport.make(dataset, period: period))
        #expect(report.renewals.map(\.index) == [1, 3])
        let first = try #require(report.renewals.first)
        #expect(first.renewed == 64)
        #expect(first.due == 110)
        #expect(first.periodTitle == "1st renewal")
        #expect(report.renewals.last?.due == 38)
        #expect(report.renewals.last?.periodTitle == "3rd and later")
    }

    @Test func cancellationsHaveApplesReasonsAndTheEarlyOnes() throws {
        let report = try #require(SubscriptionsReport.make(dataset, period: period))
        #expect(report.cancellations == 164)
        #expect(report.reasons.first { $0.name == "Canceled" }?.count == 111)
        #expect(report.reasons.first { $0.name == "Billing Issue" }?.count == 46)
        #expect(report.reasons.first { $0.name == "Price Increase" }?.count == 7)
        // Trials that lapsed and the first paid period's cancellations.
        #expect(report.earlyCancellations == 157)
        #expect(report.earlyShare.measured != nil)
    }

    @Test func territoriesCompareWithTheAppsTrialRate() throws {
        let report = try #require(SubscriptionsReport.make(dataset, period: period))
        #expect(report.territories.map(\.code) == ["US", "BR"])
        let brazil = try #require(report.territories.last)
        #expect(brazil.paid == 5)
        #expect(brazil.ended == 36)
        #expect(brazil.trialToPaid.measured?.standing == .worse)
        #expect(report.products.map(\.name) == ["Annual"])
        #expect(report.products.first?.active == 1284)
    }

    @Test func withoutSalesThereIsNoReport() {
        var dataset = dataset
        dataset.salesState = .needsVendorNumber
        #expect(SubscriptionsReport.make(dataset, period: period) == nil)
        dataset.salesState = .ready
        dataset.sellsSubscriptions = false
        #expect(SubscriptionsReport.make(dataset, period: period) == nil)
    }
}
