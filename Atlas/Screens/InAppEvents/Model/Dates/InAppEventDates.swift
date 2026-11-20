//
//  InAppEventDates.swift
//  Atlas
//

import Foundation

/// An event's three dates, with Apple's rules for them: an event lasts
/// from 15 minutes to 31 days, its card shows at most 14 days before it
/// starts and no later than its start, and App Store Connect only takes
/// dates in the future ("Supplied date must be in the future": Alba
/// 1.2.0's "7 Days of Gratitude" was set to show from a time that had
/// passed). The New Event sheet and an existing event's dates follow the
/// same rules (`InAppEventDateRule`), and the same warnings about App
/// Review's time (`InAppEventDateWarning`). Codable, for the dates a deep
/// link check was made under.
struct InAppEventDates: Hashable, Codable, Sendable {
    var publishStart: Date
    var eventStart: Date
    var eventEnd: Date

    static let shortestDuration: TimeInterval = 15 * 60
    static let longestDuration: TimeInterval = 31 * 86400
    static let longestLeadTime: TimeInterval = 14 * 86400
    /// How long App Review usually takes at most: about half of what's
    /// submitted is reviewed within a day, 90% within two
    /// (developer.apple.com/distribute/app-review). An event shows only
    /// once it's approved.
    static let reviewTime: TimeInterval = 48 * 3600
    /// How far ahead the earliest suggested time is, at least.
    static let shortestNotice: TimeInterval = 30 * 60

    init(publishStart: Date, eventStart: Date, eventEnd: Date) {
        self.publishStart = publishStart
        self.eventStart = eventStart
        self.eventEnd = eventEnd
    }

    /// A schedule's dates; nil when it lacks any of them.
    init?(_ schedule: InAppEventSchedule?) {
        guard let publish = schedule?.publishStart, let start = schedule?.eventStart, let end = schedule?.eventEnd else { return nil }
        self.init(publishStart: publish, eventStart: start, eventEnd: end)
    }

    subscript(field: InAppEventDateField) -> Date {
        get {
            switch field {
            case .publishStart: publishStart
            case .eventStart: eventStart
            case .eventEnd: eventEnd
            }
        }
        set {
            switch field {
            case .publishStart: publishStart = newValue
            case .eventStart: eventStart = newValue
            case .eventEnd: eventEnd = newValue
            }
        }
    }

    var duration: TimeInterval { eventEnd.timeIntervalSince(eventStart) }

    /// How long before the start the card shows.
    var leadTime: TimeInterval { eventStart.timeIntervalSince(publishStart) }

    /// The rules these dates break; with `now`, also a date that isn't in
    /// the future.
    func broken(now: Date?) -> [InAppEventDateRule] {
        InAppEventDateRule.broken(by: self, now: now)
    }

    /// What App Review's time may do to them at `now`: the card or the
    /// event within two days.
    func warnings(now: Date) -> [InAppEventDateWarning] {
        InAppEventDateWarning.warnings(for: self, now: now)
    }

    /// A "Shows from" that App Store Connect takes and that gives App
    /// Review its two days: two days from `now`, on the hour, kept at most
    /// 14 days before the start (and no later than it); when two days
    /// don't fit before the start, the earliest time still ahead (the next
    /// hour at least 30 minutes away). Nil when even that is after the
    /// start: then the event itself has to move.
    func suggestedPublishStart(now: Date, calendar: Calendar = .current) -> Date? {
        let lowest = eventStart.addingTimeInterval(-Self.longestLeadTime)
        var candidate = max(Self.onTheHour(now.addingTimeInterval(Self.reviewTime), calendar: calendar), lowest)
        if candidate > eventStart {
            candidate = max(Self.onTheHour(now.addingTimeInterval(Self.shortestNotice), calendar: calendar), lowest)
        }
        guard candidate > now, candidate <= eventStart else { return nil }
        return candidate
    }

    /// `date`, or the next whole hour after it.
    static func onTheHour(_ date: Date, calendar: Calendar) -> Date {
        guard let hour = calendar.dateInterval(of: .hour, for: date) else { return date }
        return hour.start == date ? date : hour.end
    }
}
