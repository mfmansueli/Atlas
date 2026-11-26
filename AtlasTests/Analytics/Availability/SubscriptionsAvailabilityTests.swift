//
//  SubscriptionsAvailabilityTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Subscriptions' card and empty states follow Apple's rules: reports
/// start the day after the first sale (trials and introductory offers
/// count), rows under 5 people are left out, and days are Pacific days.
@Suite("Analytics · Subscriptions with nothing to show yet")
struct SubscriptionsAvailabilityTests {
    typealias Data = AnalyticsTestData

    /// Noon in Los Angeles on the day after the data's last day.
    private let now = Data.through.adding(1).date.addingTimeInterval(20 * 3600)

    private func dataset(
        events: [SubscriptionEventFact] = [], active: [ActiveSubscriptionsFact] = [], subscribers: [SubscriberFact] = [],
        reports: ReportsArchive = ReportsArchive(), sales: SalesState = .ready, sells: Bool = true
    ) -> AnalyticsDataset {
        AnalyticsDataset(
            appID: Data.appID, appName: "Parcel Pal", events: events, subscribers: subscribers, active: active, reports: reports,
            salesState: sales, sellsSubscriptions: sells
        )
    }

    private func availability(_ dataset: AnalyticsDataset) -> AnalyticsTabAvailability {
        AnalyticsTabAvailability.make(.subscriptions, dataset: dataset, now: now)
    }

    private func active(paid: Int, trials: Int = 0, back: Int = 0) -> ActiveSubscriptionsFact {
        ActiveSubscriptionsFact(day: Data.through.adding(-back), appID: Data.appID, subscription: "Annual", territory: "US", paid: paid, trials: trials)
    }

    // MARK: - Nothing sold

    @Test func withNothingSoldThereAreNoSubscriptionsYet() {
        let state = availability(dataset())
        #expect(state == .noSubscriptionsSold)
        #expect(state.title == "No subscriptions sold yet")
        #expect(state.cardSummary == "None sold yet")
        #expect(!state.isAvailable)
    }

    @Test func eventsWithNoQuantityAreNotASale() {
        #expect(availability(dataset(events: [Data.event(.trialStart, 0)])) == .noSubscriptionsSold)
    }

    @Test func anAppWithoutASubscriptionHasNoSubscriptionsState() {
        #expect(availability(dataset(sells: false)) == .available)
    }

    @Test func unreadSalesLeaveItToTheSectionsNotice() {
        #expect(availability(dataset(sales: .needsVendorNumber)) == .available)
        #expect(availability(dataset(sales: .keyCannotRead)) == .available)
        #expect(availability(dataset(sales: .waiting)) == .available)
    }

    // MARK: - Trials only

    @Test func aFreeTrialCountsAsTheFirstSale() {
        let state = availability(dataset(events: [Data.event(.trialStart, 1, back: 3)]))
        #expect(state == .noPaidSubscribers(trials: 1))
        #expect(state.title == "No paid subscribers yet")
        #expect(state.cardSummary == "No paid subscribers yet")
    }

    @Test func anIntroductoryOfferCountsAsATrial() {
        #expect(SubscriptionEventKind(event: "Start Introductory Offer") == .trialStart)
        #expect(SubscriptionEventKind(event: "Start Introductory Price") == .trialStart)
    }

    @Test func trialsWithoutAPaymentAreNoPaidSubscribersEvenWhenMany() {
        let events = [Data.event(.trialStart, 6, back: 4), Data.event(.trialStart, 3, back: 1), Data.event(.cancellation, 2, reason: "Canceled")]
        #expect(availability(dataset(events: events)) == .noPaidSubscribers(trials: 9))
    }

    @Test func activeTrialsAloneAreTrialsToo() {
        #expect(availability(dataset(active: [active(paid: 0, trials: 2)])) == .noPaidSubscribers(trials: 2))
    }

    @Test func aChargeOrRenewalMeansSomeonePaid() {
        let charge = SubscriberFact(day: Data.through, appID: Data.appID, subscription: "Annual", territory: "US", charges: 1, refunds: 0, proceeds: 3)
        #expect(availability(dataset(events: [Data.event(.trialStart, 2)], subscribers: [charge])) == .tooFewSubscribers(count: 2))
        #expect(availability(dataset(events: [Data.event(.renewal, 3, periods: 2)])) == .tooFewSubscribers(count: 3))
    }

    // MARK: - Fewer than 5 people

    @Test func fourPeopleAreTooFewForRates() {
        let state = availability(dataset(events: [Data.event(.trialStart, 4, back: 3), Data.event(.paidFromTrial, 1, back: 1, periods: 1)]))
        #expect(state == .tooFewSubscribers(count: 4))
        #expect(state.title == "Too few subscribers to show rates")
        #expect(state.cardSummary == "Too few to show rates")
    }

    @Test func fivePeopleAreEnough() {
        let events = [Data.event(.trialStart, 5, back: 3), Data.event(.paidFromTrial, 1, back: 1, periods: 1)]
        #expect(availability(dataset(events: events)) == .available)
    }

    @Test func paidStartsAndTrialsAddUpToPeople() {
        let four = [Data.event(.trialStart, 3), Data.event(.paidStart, 1, periods: 1)]
        #expect(availability(dataset(events: four)) == .tooFewSubscribers(count: 4))
        let five = [Data.event(.trialStart, 3), Data.event(.paidStart, 2, periods: 1)]
        #expect(availability(dataset(events: five)) == .available)
    }

    @Test func aTrialThatPaidIsOnePersonNotTwo() {
        let soFar = SubscriptionsSoFar.make(dataset(events: [Data.event(.trialStart, 4), Data.event(.paidFromTrial, 4, periods: 1)]), now: now)
        #expect(soFar.people == 4)
        #expect(soFar.paid == 4)
        #expect(soFar.paidFromTrials == 4)
    }

    @Test func theNewestActiveCountDecides() {
        #expect(availability(dataset(active: [active(paid: 40)])) == .available)
        #expect(availability(dataset(active: [active(paid: 40, back: 30), active(paid: 3)])) == .tooFewSubscribers(count: 3))
    }

    @Test func renewalsCountPeopleOncePerDay() {
        // The same 2 people renewing every month are 2 people, not 8.
        let events = (0..<4).map { Data.event(.renewal, 2, back: $0 * 30, periods: $0 + 2) }
        #expect(availability(dataset(events: events)) == .tooFewSubscribers(count: 2))
    }

    @Test func theFullSampleHasSomethingToShow() {
        #expect(availability(Data.lumen) == .available)
    }

    // MARK: - Days and Pacific time

    @Test func reportsStartTheDayAfterTheFirstSale() {
        let soFar = SubscriptionsSoFar.make(dataset(events: [Data.event(.trialStart, 1, back: 2), Data.event(.trialStart, 1, back: 5)]), now: now)
        #expect(soFar.firstSale == Data.through.adding(-5))
        #expect(soFar.reportsStart == Data.through.adding(-4))
        #expect(SubscriptionsSoFar.make(dataset(), now: now).reportsStart == nil)
    }

    @Test func todayIsThePacificDay() throws {
        // 07:30 UTC on Nov 10 is 23:30 on Nov 9 in Los Angeles (PST, UTC−8).
        let lateNight = try #require(AnalyticsDay(iso: "2026-11-10")).date.addingTimeInterval(7.5 * 3600)
        #expect(AnalyticsDay.pacific(lateNight) == AnalyticsDay(iso: "2026-11-09"))
        #expect(AnalyticsDay.pacific(lateNight.addingTimeInterval(3600)) == AnalyticsDay(iso: "2026-11-10"))
        // In summer Los Angeles is UTC−7.
        let summer = try #require(AnalyticsDay(iso: "2026-07-01")).date.addingTimeInterval(6.5 * 3600)
        #expect(AnalyticsDay.pacific(summer) == AnalyticsDay(iso: "2026-06-30"))
        #expect(AnalyticsDay.pacific(summer.addingTimeInterval(3600)) == AnalyticsDay(iso: "2026-07-01"))
    }

    @Test func aTrialEndsOnItsPacificDay() throws {
        // A week's trial started Nov 3 ends Nov 10. At 07:30 UTC on Nov 10
        // it's still Nov 9 in Pacific time: not ended yet.
        let start = try #require(AnalyticsDay(iso: "2026-11-03"))
        let trial = SubscriptionEventFact(day: start, appID: Data.appID, kind: .trialStart, subscription: "Annual", territory: "US", quantity: 1)
        let reports = ReportsTestData.archive([.subscriptionEvents: [
            ReportsTestData.event(0, grouping: "Offer Starts", subType: "Free Trial Starts", offerType: "Free Trial", duration: "1 Week", count: 1),
        ]])
        let endDay = try #require(AnalyticsDay(iso: "2026-11-10"))
        let lateNight = endDay.date.addingTimeInterval(7.5 * 3600)
        let before = SubscriptionsSoFar.make(dataset(events: [trial], reports: reports), now: lateNight)
        #expect(before.firstTrialEnds == endDay)
        #expect(before.today == AnalyticsDay(iso: "2026-11-09"))
        #expect(!before.firstTrialHasEnded)
        let after = SubscriptionsSoFar.make(dataset(events: [trial], reports: reports), now: lateNight.addingTimeInterval(3600))
        #expect(after.firstTrialHasEnded)
    }

    @Test func theTrialLengthIsTheShortestFreeTrial() {
        let reports = ReportsTestData.archive([.subscriptionEvents: [
            ReportsTestData.event(0, grouping: "Offer Starts", subType: "Free Trial Starts", offerType: "Free Trial", duration: "1 Month", count: 1),
            ReportsTestData.event(1, grouping: "Offer Starts", subType: "Free Trial Starts", offerType: "Free Trial", duration: "1 Week", count: 1),
            ReportsTestData.event(2, grouping: "Offer Starts", subType: "Offer Code Starts", offerType: "Offer Code", duration: "3 Days", count: 1),
        ]])
        #expect(SubscriptionsSoFar.trialDays(reports) == 7)
        #expect(SubscriptionsSoFar.trialDays(ReportsArchive()) == nil)
    }

    @Test func withoutATrialLengthThereIsNoTrialEnd() {
        let soFar = SubscriptionsSoFar.make(dataset(events: [Data.event(.trialStart, 1)]), now: now)
        #expect(soFar.firstTrialEnds == nil)
        #expect(!soFar.firstTrialHasEnded)
    }
}
