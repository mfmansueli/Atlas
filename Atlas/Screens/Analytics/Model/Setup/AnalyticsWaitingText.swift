//
//  AnalyticsWaitingText.swift
//  Atlas
//

import Foundation

/// The waiting empty state's sentence (board 74 · 7): when Atlas asked,
/// how long Apple usually takes, and that each view fills in by itself.
enum AnalyticsWaitingText {
    static func text(appName: String, asked: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(asked, inSameDayAs: now) {
            return String(localized: """
            Atlas asked Apple for \(appName)’s analytics today. The first reports usually take 1 to 2 days, and each view \
            here fills in as its report arrives.
            """, comment: "kind:description")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(asked, inSameDayAs: yesterday) {
            return String(localized: """
            Atlas asked Apple for \(appName)’s analytics yesterday. The first reports usually take 1 to 2 days, and each view \
            here fills in as its report arrives.
            """, comment: "kind:description")
        }
        return String(localized: """
        Atlas asked Apple for \(appName)’s analytics on \(AnalyticsText.day(asked)). The first reports usually take 1 to 2 \
        days, and each view here fills in as its report arrives.
        """, comment: "kind:description")
    }
}
