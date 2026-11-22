//
//  LifecycleReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · offers, billing and subscribers by page")
struct LifecycleReportTests {
    typealias Rows = ReportsTestData

    private let period = AnalyticsPeriod(ending: ReportsTestData.last, length: 28)

    private var archive: ReportsArchive {
        Rows.archive([
            .subscriptionEvents: [
                Rows.event(
                    3, grouping: "Offer Starts", subType: "Free Trial Starts", offerType: "Free Trial", offer: "1 week free", duration: "1 Week", count: 200
                ),
                Rows.event(
                    3, grouping: "Paid Subscriptions from Offers", subType: "Full Price from Free Trial", offerType: "Free Trial", offer: "1 week free",
                    count: 80
                ),
                Rows.event(3, grouping: "Voluntary Churn", subType: "Voluntary Churn from Free Trials", reason: "Turned off auto-renew", count: 100),
                Rows.event(
                    5, grouping: "Offer Starts", subType: "Offer Code Starts", offerType: "Offer Code", offer: "PODCAST30", duration: "1 Month", page: "Sleep",
                    count: 60
                ),
                Rows.event(
                    5, grouping: "Paid Subscriptions from Offers", subType: "Full Price from Paid Offer", offerType: "Offer Code", offer: "PODCAST30",
                    page: "Sleep", count: 4
                ),
                Rows.event(
                    1, grouping: "Offer Starts", subType: "Paid Offer Starts", offerType: "Promotional Offer", offer: "Holiday", duration: "2 Months", count: 20
                ),
                Rows.event(4, grouping: "Entered Billing Issue", subType: "Entered Billing Retry from Paid", count: 83),
                Rows.event(4, grouping: "Recoveries from Billing Issue", subType: "Paid Recoveries from Billing Retry", count: 29),
                Rows.event(4, grouping: "Involuntary Churn", subType: "Involuntary Churn from Paid", reason: "Billing Issue", count: 54),
                Rows.event(4, grouping: "Exits", subType: "Plan Changes", plan: "Upgrade", count: 6),
            ],
            .subscriptionStates: [
                Rows.fact(0, ["Billing issue", "Billing retry", "Pro Monthly", "", "", "", "", "", "US"], [31]),
                Rows.fact(0, ["Billing issue", "Grace period", "Pro Monthly", "", "", "", "", "", "US"], [4]),
                Rows.fact(1, ["Billing issue", "Billing retry", "Pro Monthly", "", "", "", "", "", "US"], [99]),
            ],
        ])
    }

    @Test func billingCountsWhoCouldntBeChargedRecoveredAndLost() throws {
        let report = try #require(LifecycleReport.make(archive, period: period))
        #expect(report.couldNotCharge == 83)
        #expect(report.recovered == 29)
        #expect(report.lost == 54)
        // Only the newest state day counts.
        #expect(report.inBillingRetry == 31)
        #expect(report.inGracePeriod == 4)
    }

    @Test func anOfferThatPaysLessThanAverageStandsWorse() throws {
        let report = try #require(LifecycleReport.make(archive, period: period))
        let podcast = try #require(report.offers.first { $0.name == "PODCAST30" })
        #expect(podcast.started == 60)
        #expect(podcast.paidAfterwards == 4)
        #expect(podcast.standing == .worse)
        let average = try #require(report.offerAverage)
        #expect(abs(average - 84.0 / 280.0) < 0.0001)
    }

    @Test func anOfferTooYoungToRenewHasNoRateYet() throws {
        let report = try #require(LifecycleReport.make(archive, period: period))
        let holiday = try #require(report.offers.first { $0.name == "Holiday" })
        #expect(holiday.rate == .missing)
        #expect(holiday.firstRenewal == Rows.last.adding(-1 + 60))
    }

    @Test func subscribersSplitByPageAddUp() {
        let all = archive.subscribers(in: period) { _ in true }
        #expect(all.trials == 200)
        #expect(all.trialConverted == 80)
        #expect(all.trialLapsed == 100)
        #expect(all.trialToPaidFraction == 80.0 / 180.0)
        let sleep = archive.subscribers(in: period) { ReportsArchive.pageName($0, defaultName: "Default") == "Sleep" }
        #expect(sleep.paid == 4)
        #expect(archive.hasPageRows)
    }

    @Test func planChangesAreCounted() throws {
        let report = try #require(LifecycleReport.make(archive, period: period))
        #expect(report.planChanges.first { $0.name == String(localized: "Upgraded") }?.count == 6)
    }
}
