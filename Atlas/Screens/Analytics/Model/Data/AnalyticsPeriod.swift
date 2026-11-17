//
//  AnalyticsPeriod.swift
//  Atlas
//

import Foundation

/// A run of days, both ends included, e.g. the last 28 days of data.
struct AnalyticsPeriod: Hashable, Sendable {
    var first: AnalyticsDay
    var last: AnalyticsDay

    /// The `length` days ending on `last`.
    init(ending last: AnalyticsDay, length: Int) {
        first = last.adding(1 - max(length, 1))
        self.last = last
    }

    init(first: AnalyticsDay, last: AnalyticsDay) {
        self.first = first
        self.last = last
    }

    var length: Int { last.number - first.number + 1 }

    /// The same number of days right before this one.
    var previous: AnalyticsPeriod {
        AnalyticsPeriod(ending: first.adding(-1), length: length)
    }

    var days: [AnalyticsDay] {
        (first.number...max(first.number, last.number)).map(AnalyticsDay.init(number:))
    }

    func contains(_ day: AnalyticsDay) -> Bool {
        day >= first && day <= last
    }

    /// "Oct 13–Nov 9".
    var text: String {
        AnalyticsText.range(first.date, last.date)
    }
}
