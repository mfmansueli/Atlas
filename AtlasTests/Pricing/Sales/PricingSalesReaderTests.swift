//
//  PricingSalesReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Analytics downloaded, read into one product's 90 and 28 days per
/// territory, and each sales state.
@Suite("Pricing sales reader")
struct PricingSalesReaderTests {
    private typealias Data = PricingSalesTestData

    // MARK: - Windows

    @Test func windowsAreTheLast90And28Days() {
        let input = Data.input(engagement: [
            Data.views(10), Data.views(20, back: 27), Data.views(40, back: 28), Data.views(80, back: 89), Data.views(160, back: 90),
        ])
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.recentSignals["BRA"]?.pageViews == 30)
        #expect(sales.signals["BRA"]?.pageViews == 150)
        #expect(sales.readThrough == Data.through.date)
    }

    @Test func signalsAreKeyedByTerritoryIDAndSkipUnknownTerritories() {
        let input = Data.input(engagement: [Data.views(10, territory: "BR"), Data.views(7, territory: "DE"), Data.views(5, territory: "")])
        let signals = Data.reader(input).salesData(for: Data.annual).signals
        #expect(signals["BRA"]?.pageViews == 10)
        #expect(signals["DEU"]?.pageViews == 7)
        #expect(signals.count == 2)
    }

    @Test func pageViewsAreTheAppsAndStartsTheProducts() {
        let input = Data.input(
            engagement: [Data.views(500, downloads: 60)],
            events: [Data.event(.trialStart, 9), Data.event(.trialStart, 4, product: Data.monthly)]
        )
        let reader = Data.reader(input)
        let annual = reader.salesData(for: Data.annual).signals["BRA"]
        let monthly = reader.salesData(for: Data.monthly).signals["BRA"]
        #expect(annual?.pageViews == 500)
        #expect(monthly?.pageViews == 500)
        #expect(annual?.downloads == 60)
        #expect(annual?.trialStarts == 9)
        #expect(monthly?.trialStarts == 4)
    }

    @Test func startsAreTrialsPlusPaidWithoutATrial() throws {
        let input = Data.input(
            engagement: [Data.views(800)],
            events: [Data.event(.trialStart, 5), Data.event(.paidStart, 2), Data.event(.paidFromTrial, 3), Data.event(.renewal, 9)],
            subscribers: [Data.proceeds(12.5), Data.proceeds(7.5, back: 3), Data.proceeds(100, back: 95)]
        )
        let signal = try #require(Data.reader(input).salesData(for: Data.annual).signals["BRA"])
        #expect(signal.starts == 7)
        #expect(signal.trialStarts == 5)
        #expect(signal.paidStarts == 5)
        #expect(signal.proceeds == 20)
    }

    @Test func linesWithoutAnIDMatchOnTheReferenceName() {
        let byName = Data.event(.trialStart, 3, keepsID: false)
        var renamed = Data.event(.trialStart, 5, keepsID: false)
        renamed.subscription = " annual "
        var otherID = Data.event(.trialStart, 11)
        otherID.subscriptionID = "someone-else"
        let input = Data.input(engagement: [Data.views(100)], events: [byName, renamed, otherID])
        #expect(Data.reader(input).salesData(for: Data.annual).signals["BRA"]?.trialStarts == 8)
        #expect(PricingSalesReader.matches(subscriptionID: nil, name: "", product: Data.annual) == false)
    }

    @Test func readThroughIsTheLastDayBothSourcesCover() {
        let input = Data.input(engagement: [Data.views(10, back: 2), Data.views(10, back: 30)])
        let reader = Data.reader(input)
        #expect(reader.readThrough == Data.through.adding(-2))
        #expect(reader.coveredFrom == Data.through.adding(-30))
    }

    // MARK: - Availability

    @Test func turnedOffLeavesNothing() {
        let input = Data.input(engagement: [Data.views(100)], events: [Data.event(.trialStart, 4)], usesSalesData: false)
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.availability == .turnedOff)
        #expect(sales.signals.isEmpty)
        #expect(!sales.canRead)
    }

    @Test func aKeyThatCantReadSalesKeepsPageViewsOnly() {
        let input = Data.input(engagement: [Data.views(100)], events: [Data.event(.trialStart, 4)], state: .keyCannotRead)
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.availability == .roleCannotRead)
        #expect(sales.signals["BRA"]?.pageViews == 100)
        #expect(sales.signals["BRA"]?.starts == 0)
    }

    @Test func nothingDownloadedIsNotRead() {
        let sales = Data.reader(Data.input(salesDays: [], state: .needsVendorNumber)).salesData(for: Data.annual)
        #expect(sales.availability == .notRead)
        #expect(sales.signals.isEmpty)
        #expect(sales.readThrough == nil)
    }

    @Test func pageViewsWithoutSalesAndTrendsAreNotRead() {
        let input = Data.input(engagement: [Data.views(100)], salesDays: [], state: .needsVendorNumber)
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.availability == .notRead)
        #expect(sales.signals["BRA"]?.pageViews == 100)
    }

    @Test func inAppPurchasesAreNotReadYet() {
        let input = Data.input(engagement: [Data.views(100)], events: [Data.event(.trialStart, 4)])
        #expect(Data.reader(input).salesData(for: Data.lifetime).availability == .notRead)
    }

    @Test func readDaysWithoutEventsAreNoSalesYet() {
        // Alba: every day answered 404, page views arrived.
        let input = Data.input(engagement: [Data.views(79)])
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.availability == .noSalesYet)
        #expect(sales.canRead)
        #expect(sales.signals["BRA"]?.pageViews == 79)
        #expect(sales.signals["BRA"]?.starts == 0)
    }

    @Test func anotherProductsSalesAreNoSalesYetForThisOne() {
        let input = Data.input(engagement: [Data.views(79)], events: [Data.event(.trialStart, 2, product: Data.monthly)])
        let reader = Data.reader(input)
        #expect(reader.salesData(for: Data.annual).availability == .noSalesYet)
        #expect(reader.salesData(for: Data.monthly).availability == .available)
    }

    @Test func emptyDaysDontChangeTheWindows() {
        // Sales on 2 of 200 read days; the rest were Apple's 404.
        let input = Data.input(engagement: [Data.views(300)], events: [Data.event(.trialStart, 3), Data.event(.trialStart, 2, back: 50)])
        let sales = Data.reader(input).salesData(for: Data.annual)
        #expect(sales.availability == .available)
        #expect(sales.recentSignals["BRA"]?.trialStarts == 3)
        #expect(sales.signals["BRA"]?.trialStarts == 5)
    }

    // MARK: - Results and subscribers

    @Test func comparisonReadsTheDaysEitherSideOfAChange() throws {
        let change = Data.through.adding(-40)
        let input = Data.input(
            engagement: [Data.views(200, back: 45), Data.views(300, back: 40), Data.views(1, back: 70), Data.views(1)],
            events: [Data.event(.trialStart, 31, back: 45), Data.event(.trialStart, 40, back: 30), Data.event(.trialStart, 99, back: 69)]
        )
        let sales = try #require(Data.reader(input).comparison(for: Data.annual, territoryIDs: ["BRA", "DEU"], changedOn: change.date))
        let brazil = try #require(sales["BRA"])
        #expect(brazil.before.pageViews == 200)
        #expect(brazil.before.starts == 31)
        #expect(brazil.after.pageViews == 300)
        #expect(brazil.after.starts == 40)
        #expect(brazil.before.days == 28)
        #expect(brazil.after.days == 28)
        #expect(sales["DEU"]?.after.starts == 0)
    }

    @Test func comparisonCountsOnlyTheDaysTheReportsCover() throws {
        let input = Data.input(engagement: [Data.views(10), Data.views(10, back: 60)])
        let sales = try #require(Data.reader(input).comparison(for: Data.annual, territoryIDs: ["BRA"], changedOn: Data.through.adding(-10).date))
        #expect(sales["BRA"]?.after.days == 11)
        #expect(sales["BRA"]?.before.days == 28)
    }

    @Test func comparisonAndSubscribersNeedReadableSales() {
        let reader = Data.reader(Data.input(engagement: [Data.views(10)], usesSalesData: false))
        #expect(reader.comparison(for: Data.annual, territoryIDs: ["BRA"], changedOn: Data.through.date) == nil)
        #expect(reader.subscribers(for: Data.annual) == nil)
    }

    @Test func subscribersAreTheNewestDaysPaidAndTrials() {
        func active(_ back: Int, _ territory: String, paid: Int, trials: Int) -> ActiveSubscriptionsFact {
            ActiveSubscriptionsFact(
                day: Data.through.adding(-back), appID: Data.appID, subscription: "Annual", territory: territory, paid: paid, trials: trials,
                subscriptionID: Data.annual.id
            )
        }
        let input = Data.input(
            events: [Data.event(.trialStart, 1)],
            active: [active(0, "US", paid: 120, trials: 8), active(0, "BR", paid: 0, trials: 0), active(7, "US", paid: 900, trials: 0)]
        )
        #expect(Data.reader(input).subscribers(for: Data.annual) == ["USA": 128])
    }
}
