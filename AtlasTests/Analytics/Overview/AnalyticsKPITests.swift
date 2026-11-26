//
//  AnalyticsKPITests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the Overview's four numbers")
struct AnalyticsKPITests {
    private let period = AnalyticsPeriod(ending: AnalyticsDay(number: 20400), length: 28)

    private func funnel(proceeds: Decimal?, previous: Decimal?) -> FunnelReport {
        FunnelReport(
            days: 28, period: period, previous: period.previous, isNew: false, steps: [],
            totals: FunnelTotals(proceeds: proceeds), previousTotals: FunnelTotals(proceeds: previous),
            callout: FunnelCallout(kind: .steady, title: "", text: "")
        )
    }

    private func stability(new: Int, old: Int) -> StabilityReport {
        StabilityReport(
            period: period,
            latest: .init(version: "1.4", crashes: new, sessions: 1000, devices: 10),
            previous: .init(version: "1.3", crashes: old, sessions: 1000, devices: 10),
            comparison: new > old ? .higher(.sure) : .same, devices: [], days: []
        )
    }

    private func subscriptions(active: Int?) -> SubscriptionsReport {
        SubscriptionsReport(
            period: period, active: active, activeChange: "+3%", trialToPaid: .missing, trialToPaidComparison: nil, trialAverage: nil,
            proceeds: 0, proceedsChange: nil, refunds: 0, charges: 0, renewals: [], cancellations: 0, reasons: [], earlyCancellations: 0,
            products: [], territories: []
        )
    }

    @Test func fourNumbersForAnAppThatSellsASubscriptionAndTwoWithout() {
        #expect(AnalyticsKPI.make(AnalyticsKPI.Inputs()).map(\.kind) == [.rating, .proceeds, .subscribers, .crashes])
        #expect(AnalyticsKPI.make(AnalyticsKPI.Inputs(sellsSubscriptions: false)).map(\.kind) == [.rating, .crashes])
    }

    @Test func ratingShowsTheVersionsAndOpensReviews() {
        let rating = OverviewRating(average: 4.6, version: "1.4", versionAverage: 3.9, previousVersion: "1.3", previousAverage: 4.7, isLower: true)
        let number = AnalyticsKPI.rating(rating, isLoading: false)
        #expect(number.value == RatingsSummary.starsText(4.6))
        #expect(number.detail == "\(RatingsSummary.starsText(3.9)) on 1.4 · \(RatingsSummary.starsText(4.7)) on 1.3")
        #expect(number.tone == .warning)
        #expect(number.link == "Reviews")
        #expect(number.accessibilityText.hasPrefix("Rating \(ReviewText.rating(4.6)) stars, \(ReviewText.rating(3.9)) on version 1.4"))
    }

    @Test func ratingWithoutVersionsShowsTheOverallAverageOnly() {
        let number = AnalyticsKPI.rating(OverviewRating(average: 4.2), isLoading: false)
        #expect(number.detail == "All versions")
        #expect(number.tone == .neutral)
        #expect(AnalyticsKPI.rating(nil, isLoading: false).detail == "No ratings yet")
        #expect(AnalyticsKPI.rating(nil, isLoading: true).isLoading)
    }

    @Test func proceedsSayTheChangeAfterApplesCommission() {
        let number = AnalyticsKPI.proceeds(funnel(proceeds: 6040, previous: 5645), gap: nil, availability: .available)
        #expect(number.value == AnalyticsText.dollars(6040))
        #expect(number.detail == "+7% · after Apple’s commission")
        #expect(number.link == "By Country")
    }

    @Test func proceedsWithoutSalesSayWhy() {
        let gap = AnalyticsKPI.proceeds(funnel(proceeds: nil, previous: nil), gap: .needsVendorNumber, availability: .available)
        #expect(gap.value == "—")
        #expect(gap.detail == FunnelGap.needsVendorNumber.text)
        #expect(gap.tone == .warning)
        #expect(gap.link == nil)
        let none = AnalyticsKPI.proceeds(funnel(proceeds: 0, previous: nil), gap: nil, availability: .noSubscriptionsSold)
        #expect(none.detail == AnalyticsTabAvailability.noSubscriptionsSold.cardSummary)
    }

    @Test func subscribersSayTheSameCaseAsTheirCard() {
        let ready = AnalyticsKPI.subscribers(subscriptions(active: 1284), gap: nil, availability: .available)
        #expect(ready.value == AnalyticsText.count(1284))
        #expect(ready.detail == "+3% vs before")
        #expect(ready.link == "Subscriptions")
        let none = AnalyticsKPI.subscribers(nil, gap: nil, availability: .noSubscriptionsSold)
        #expect(none.value == "—")
        #expect(none.detail == "None sold yet")
        let few = AnalyticsKPI.subscribers(nil, gap: nil, availability: .tooFewSubscribers(count: 3))
        #expect(few.value == "3")
        #expect(few.detail == AnalyticsTabAvailability.tooFewSubscribers(count: 3).cardSummary)
    }

    @Test func crashesCompareTheNewestVersionWithTheOneBefore() {
        let number = AnalyticsKPI.crashes(stability(new: 68, old: 21), availability: .available, hasTab: true)
        #expect(number.title == "Crashes on 1.4")
        #expect(number.value == AnalyticsText.perThousand(68))
        #expect(number.detail?.hasSuffix("1.3 · per 1,000 sessions") == true)
        #expect(number.tone == .warning)
        #expect(number.link == "Stability")
        #expect(number.accessibilityText.contains("per 1,000 sessions"))
    }

    @Test func aVersionTooNewShowsADashAndThePreviousRate() {
        let availability = AnalyticsTabAvailability.versionTooNew(version: "1.4", previous: "1.3", previousRate: 2.1)
        let number = AnalyticsKPI.crashes(nil, availability: availability, hasTab: true)
        #expect(number.title == "Crashes on 1.4")
        #expect(number.value == "—")
        #expect(number.detail == "Too new to tell · 1.3 had \(AnalyticsText.perThousand(2.1))")
        let alone = AnalyticsKPI.crashes(nil, availability: .versionTooNew(version: "1.0", previous: nil, previousRate: nil), hasTab: false)
        #expect(alone.detail == "Too new to tell")
        #expect(alone.link == nil)
    }
}
