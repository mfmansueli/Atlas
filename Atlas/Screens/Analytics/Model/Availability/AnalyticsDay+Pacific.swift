//
//  AnalyticsDay+Pacific.swift
//  Atlas
//

import Foundation

/// Apple's reports run on Pacific time: a sale at 11 p.m. in Los Angeles
/// belongs to that day, even when it's already the next day in UTC or on
/// this Mac. `AnalyticsDay` keeps the report's own date, so "today" has to
/// be worked out the same way before comparing with it.
extension AnalyticsDay {
    /// The time zone Apple's sales and analytics reports use.
    static let pacificTimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    /// The Pacific calendar day `date` falls on, as the reports would file it.
    static func pacific(_ date: Date) -> AnalyticsDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacificTimeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let day = Calendar.gmtGregorian.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) else {
            return AnalyticsDay(date)
        }
        return AnalyticsDay(day)
    }
}
