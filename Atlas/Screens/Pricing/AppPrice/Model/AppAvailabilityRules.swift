//
//  AppAvailabilityRules.swift
//  Atlas
//

import Foundation

/// What App Store Connect accepts for an app's first availability. A
/// pre-order is for an app that isn't released yet, with a release date
/// Apple's help puts between a couple of days and 180 days away; App
/// Store Connect has the last word (the push says what it refused).
enum AppAvailabilityRules {
    static let preOrderMinimumDays = 2
    static let preOrderMaximumDays = 180

    /// Apple's date format, "2026-12-20", in this Mac's calendar.
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The day as a date at its start, or nil for anything but "2026-12-20".
    static func date(from day: String, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components), Self.day(date, calendar: calendar) == day else { return nil }
        return date
    }

    static func earliestReleaseDate(today: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: preOrderMinimumDays, to: calendar.startOfDay(for: today)) ?? today
    }

    static func latestReleaseDate(today: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: preOrderMaximumDays, to: calendar.startOfDay(for: today)) ?? today
    }

    /// A pre-order's default release date: four weeks from today.
    static func suggestedReleaseDate(today: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 28, to: calendar.startOfDay(for: today)) ?? today
    }

    static func problems(for setup: AppAvailabilitySetup, today: Date, calendar: Calendar = .current) -> [AppAvailabilityProblem] {
        var problems: [AppAvailabilityProblem] = []
        if setup.availableCount == 0 { problems.append(.noTerritory) }
        if let releaseDay = setup.preOrderReleaseDate, let problem = problem(releaseDay: releaseDay, today: today, calendar: calendar) {
            problems.append(problem)
        }
        return problems
    }

    /// What's wrong with a pre-order's release date, if anything.
    static func problem(releaseDay: String, today: Date, calendar: Calendar = .current) -> AppAvailabilityProblem? {
        guard let release = date(from: releaseDay, calendar: calendar) else { return .invalidReleaseDate }
        let earliest = earliestReleaseDate(today: today, calendar: calendar)
        let latest = latestReleaseDate(today: today, calendar: calendar)
        if release < earliest { return .releaseDateTooSoon(earliest: day(earliest, calendar: calendar)) }
        if release > latest { return .releaseDateTooLate(latest: day(latest, calendar: calendar)) }
        return nil
    }
}
