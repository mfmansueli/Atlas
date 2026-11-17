//
//  AnalyticsDayTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · days and periods")
struct AnalyticsDayTests {
    @Test func aDayReadsAndWritesAppleDates() throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        #expect(day.iso == "2026-11-09")
        #expect(day.adding(1).iso == "2026-11-10")
        #expect(day.adding(-9).iso == "2026-10-31")
        #expect(AnalyticsDay(iso: "9 Nov") == nil)
        #expect(AnalyticsDay(day.date) == day)
    }

    @Test func aPeriodEndsOnItsLastDayAndKnowsThePreviousOne() throws {
        let last = try #require(AnalyticsDay(iso: "2026-11-09"))
        let period = AnalyticsPeriod(ending: last, length: 28)
        #expect(period.first.iso == "2026-10-13")
        #expect(period.length == 28)
        #expect(period.days.count == 28)
        #expect(period.previous.first.iso == "2026-09-15")
        #expect(period.previous.last.iso == "2026-10-12")
        #expect(period.contains(last))
        #expect(!period.contains(last.adding(1)))
    }

    @Test func aDayIsStoredAsOneNumber() throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let data = try JSONEncoder().encode([day])
        #expect(String(data: data, encoding: .utf8) == "[\(day.number)]")
        #expect(try JSONDecoder().decode([AnalyticsDay].self, from: data) == [day])
    }
}
