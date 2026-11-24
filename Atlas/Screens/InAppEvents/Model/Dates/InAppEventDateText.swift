//
//  InAppEventDateText.swift
//  Atlas
//

import Foundation

/// How an event's dates are written in what Atlas says about them: the
/// day, month and time in the person's time zone ("Nov 18, 9:00 PM"),
/// "today at 9:00 PM" on its own day, how far off a time is ("in 20
/// hours") and the zone itself. Tests pass their own zone and locale.
struct InAppEventDateText: Hashable, Sendable {
    var timeZone: TimeZone = .current
    var locale: Locale = .current

    static let current = InAppEventDateText()

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }

    /// "Nov 18, 9:00 PM".
    func date(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day().hour().minute())
    }

    /// "Nov 18".
    func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day())
    }

    /// "9:00 PM".
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).hour().minute())
    }

    /// "Nov 18 at 9:00 PM", or "today at 9:00 PM" on `now`'s day.
    func dayAndTime(_ date: Date, now: Date) -> String {
        calendar.isDate(date, inSameDayAs: now)
            ? String(localized: "today at \(time(date))")
            : String(localized: "\(day(date)) at \(time(date))")
    }

    /// "in 20 hours", "in 45 minutes": how long until `date`, rounded down.
    func timeUntil(_ date: Date, from now: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes < 60 { return minutes == 1 ? String(localized: "in 1 minute") : String(localized: "in \(minutes) minutes") }
        let hours = minutes / 60
        return hours == 1 ? String(localized: "in 1 hour") : String(localized: "in \(hours) hours")
    }

    /// "Brasilia Standard Time (GMT-3)": the zone the dates are shown in.
    var zoneName: String {
        let name = timeZone.localizedName(for: .generic, locale: locale) ?? timeZone.identifier
        let seconds = timeZone.secondsFromGMT()
        guard seconds != 0 else { return "\(name) (GMT)" }
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        let offset = minutes == 0 ? "\(hours)" : String(format: "%d:%02d", hours, minutes)
        let sign = seconds < 0 ? "-" : "+"
        return String(localized: "\(name) (GMT\(sign)\(offset))", comment: "kind:other")
    }
}
