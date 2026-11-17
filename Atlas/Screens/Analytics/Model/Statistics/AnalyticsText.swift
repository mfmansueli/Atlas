//
//  AnalyticsText.swift
//  Atlas
//

import Foundation

/// How Analytics writes numbers: grouped counts, one-decimal rates,
/// percentage points and day ranges.
enum AnalyticsText {
    /// "184,200".
    static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// "5.4%".
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(1)))
    }

    /// "80%".
    static func wholePercent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "+0.4 pt" or "−1.2 pt".
    static func points(_ points: Double) -> String {
        let sign = points >= 0 ? "+" : "−"
        return String(localized: "\(sign)\(abs(points).formatted(.number.precision(.fractionLength(1)))) pt")
    }

    /// A count's change against an earlier one: "+7%", "−5%", or nil
    /// without something to divide by.
    static func change(_ value: Int?, from previous: Int?) -> String? {
        guard let value, let previous, previous > 0 else { return nil }
        let percent = (Double(value - previous) / Double(previous) * 100).rounded()
        let sign = percent >= 0 ? "+" : "−"
        return "\(sign)\(Int(abs(percent)))%"
    }

    /// "$4,920", in US dollars.
    static func dollars(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// "Nov 9".
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day())
    }

    /// When something last happened, against `now`: "today at 15:04",
    /// "yesterday at 08:12" or "Nov 9 at 08:12", in the Mac's time zone.
    static func moment(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "today at \(time)") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "yesterday at \(time)")
        }
        return String(localized: "\(date.formatted(.dateTime.month(.abbreviated).day())) at \(time)")
    }

    /// "Oct 13–Nov 9".
    static func range(_ start: Date, _ end: Date) -> String {
        "\(day(start))–\(day(end))"
    }
}
