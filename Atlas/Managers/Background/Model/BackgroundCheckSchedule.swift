//
//  BackgroundCheckSchedule.swift
//  Atlas
//

import Foundation

/// When Atlas next looks at App Store Connect on its own, and the line
/// the menu bar's menu says it with: "Last checked today at 18:20 · next
/// check at 19:20".
enum BackgroundCheckSchedule {
    /// The next check: one interval after the last, at once when there
    /// hasn't been one, never while paused or with "Only when I ask".
    static func nextCheck(after last: Date?, interval: CheckInterval, isPaused: Bool, now: Date) -> Date? {
        guard !isPaused, let seconds = interval.seconds else { return nil }
        guard let last else { return now }
        return max(now, last.addingTimeInterval(seconds))
    }

    static func isDue(after last: Date?, interval: CheckInterval, isPaused: Bool, now: Date) -> Bool {
        nextCheck(after: last, interval: interval, isPaused: isPaused, now: now).map { $0 <= now } ?? false
    }

    /// "Last checked today at 18:20 · next check at 19:20".
    static func statusLine(
        last: Date?,
        interval: CheckInterval,
        isPaused: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let lastPart = last.map { String(localized: "Last checked \(moment($0, now: now, calendar: calendar))") }
            ?? String(localized: "Not checked yet")
        if isPaused { return lastPart + String(localized: " · paused") }
        guard let next = nextCheck(after: last, interval: interval, isPaused: false, now: now) else {
            return lastPart + String(localized: " · checks only when you ask")
        }
        guard next > now else { return lastPart + String(localized: " · checking soon") }
        return lastPart + String(localized: " · next check \(nextMoment(next, now: now, calendar: calendar))")
    }

    /// "today at 18:20", "yesterday at 18:20", "17 Nov at 18:20".
    private static func moment(_ date: Date, now: Date, calendar: Calendar) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "today at \(time)") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "yesterday at \(time)")
        }
        return String(localized: "\(date.formatted(.dateTime.day().month(.abbreviated))) at \(time)")
    }

    /// "at 19:20" today, "tomorrow at 9:00" after.
    private static func nextMoment(_ date: Date, now: Date, calendar: Calendar) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "at \(time)") }
        return String(localized: "tomorrow at \(time)")
    }
}
