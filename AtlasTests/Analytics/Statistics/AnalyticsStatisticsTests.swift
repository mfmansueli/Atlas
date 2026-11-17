//
//  AnalyticsStatisticsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · rates, ranges and verdicts")
struct AnalyticsStatisticsTests {
    // MARK: - One rate

    @Test func aRateHasItsWilsonRange() throws {
        // Germany on the design's board: 260 downloads from 1,480 page views.
        let rate = try #require(AnalyticsStatistics.rate(count: 260, total: 1480).measured)
        #expect(abs(rate.value - 0.1757) < 0.0001)
        #expect(abs(rate.low - 0.160) < 0.002)
        #expect(abs(rate.high - 0.192) < 0.002)
        #expect(rate.standing == nil)
    }

    @Test func fewerThanThirtyBeforeOrThreeInTheStepIsTooFew() {
        #expect(AnalyticsStatistics.rate(count: 1, total: 40) == .tooFew(count: 1, total: 40))
        #expect(AnalyticsStatistics.rate(count: 12, total: 29) == .tooFew(count: 12, total: 29))
        #expect(AnalyticsStatistics.rate(count: 3, total: 30).measured != nil)
        #expect(AnalyticsStatistics.rate(count: 1, total: 40).text == "1 of 40")
    }

    @Test func missingCountsAreMissing() {
        #expect(AnalyticsStatistics.rate(count: nil, total: 100) == .missing)
        #expect(AnalyticsStatistics.rate(count: 5, total: nil) == .missing)
        #expect(AnalyticsRate.missing.text == "—")
    }

    @Test func betterOrWorseOnlyWhenTheWholeRangeIsBeyondTheAverage() {
        #expect(AnalyticsStatistics.rate(count: 260, total: 1480, average: 0.316).measured?.standing == .worse)
        #expect(AnalyticsStatistics.rate(count: 1190, total: 3610, average: 0.316).measured?.standing == .better)
        // 31 of 100 against 31.6%: the range includes the average.
        #expect(AnalyticsStatistics.rate(count: 31, total: 100, average: 0.316).measured?.standing == .same)
    }

    @Test func theMeterFillsWithATighterRange() {
        #expect(AnalyticsStatistics.rate(count: 3120, total: 9870).measured?.bars == 3)
        #expect(AnalyticsStatistics.rate(count: 12, total: 100).measured?.bars == 1)
        #expect(AnalyticsStatistics.rate(count: 60, total: 300).measured?.bars == 2)
        #expect(AnalyticsStatistics.rate(count: 60, total: 300).measured?.sureness == "Fairly sure")
    }

    // MARK: - Two periods

    @Test func aClearDropIsLowerAndSure() {
        // The design's 28 days: 9,870 of 184,200 against 10,420 of 171,900.
        let comparison = AnalyticsStatistics.compare(count: 9870, total: 184_200, previousCount: 10420, previousTotal: 171_900)
        #expect(comparison.outcome == .lower(.sure))
        #expect(comparison.zScore < -2.58)
        #expect(comparison.points.map { ($0 * 10).rounded() } == -7)
        #expect(comparison.pointsText == AnalyticsText.points(comparison.points ?? 0))
        #expect(AnalyticsText.points(-0.7).hasPrefix("−"))
        #expect(comparison.outcome.title == "lower, sure")
    }

    @Test func aSmallDifferenceIsAboutTheSame() {
        let comparison = AnalyticsStatistics.compare(count: 3120, total: 9870, previousCount: 3300, previousTotal: 10420)
        #expect(comparison.outcome == .same)
        #expect(comparison.outcome.verdict == "About the same")
    }

    @Test func betweenNinetyAndNinetyNinePercentIsFairlySure() {
        let comparison = AnalyticsStatistics.compare(count: 130, total: 1000, previousCount: 100, previousTotal: 1000)
        #expect(comparison.outcome == .higher(.fairlySure))
    }

    @Test func comparingNeedsAHundredAndFiveOnBothSides() {
        #expect(AnalyticsStatistics.compare(count: 52, total: 1110, previousCount: 41, previousTotal: 99).outcome == .tooFew)
        #expect(AnalyticsStatistics.compare(count: 4, total: 400, previousCount: 41, previousTotal: 1020).outcome == .tooFew)
        #expect(AnalyticsStatistics.compare(count: nil, total: 400, previousCount: 41, previousTotal: 1020) == .tooFew)
        #expect(PeriodComparison.tooFew.pointsText.isEmpty)
    }

    // MARK: - Text

    @Test func countsChangeAgainstAnEarlierOne() {
        #expect(AnalyticsText.change(184_200, from: 171_900) == "+7%")
        #expect(AnalyticsText.change(9870, from: 10420) == "−5%")
        #expect(AnalyticsText.change(10, from: 0) == nil)
        #expect(AnalyticsText.change(nil, from: 5) == nil)
    }

    @Test func aMomentIsSaidAgainstNow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 15, minute: 30)))
        let earlier = try #require(calendar.date(byAdding: .hour, value: -3, to: now))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let lastWeek = try #require(calendar.date(byAdding: .day, value: -6, to: now))
        #expect(AnalyticsText.moment(earlier, now: now, calendar: calendar).hasPrefix("today at "))
        #expect(AnalyticsText.moment(yesterday, now: now, calendar: calendar).hasPrefix("yesterday at "))
        let older = AnalyticsText.moment(lastWeek, now: now, calendar: calendar)
        #expect(!older.hasPrefix("today") && !older.hasPrefix("yesterday"))
        #expect(older.contains(" at "))
    }
}
