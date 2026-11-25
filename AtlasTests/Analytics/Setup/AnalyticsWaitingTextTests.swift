//
//  AnalyticsWaitingTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 74 · 7: the waiting empty state says when Atlas asked.
@Suite("AnalyticsWaitingText")
struct AnalyticsWaitingTextTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_794_816_000) // Nov 16, 2026, 08:00 UTC

    @Test func todayYesterdayOrTheDay() {
        let today = AnalyticsWaitingText.text(appName: "Parcel Pal", asked: now.addingTimeInterval(-3600), now: now, calendar: calendar)
        #expect(today.hasPrefix("Atlas asked Apple for Parcel Pal’s analytics today."))
        let yesterday = AnalyticsWaitingText.text(appName: "Parcel Pal", asked: now.addingTimeInterval(-86400), now: now, calendar: calendar)
        #expect(yesterday.hasPrefix("Atlas asked Apple for Parcel Pal’s analytics yesterday."))
        let earlier = now.addingTimeInterval(-5 * 86400)
        let older = AnalyticsWaitingText.text(appName: "Parcel Pal", asked: earlier, now: now, calendar: calendar)
        #expect(older.hasPrefix("Atlas asked Apple for Parcel Pal’s analytics on \(AnalyticsText.day(earlier))."))
    }

    @Test func itSaysHowLongAppleTakes() {
        let text = AnalyticsWaitingText.text(appName: "Lumen", asked: now, now: now, calendar: calendar)
        #expect(text.contains("1 to 2 days"))
    }
}
