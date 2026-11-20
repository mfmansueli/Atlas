//
//  InAppEventDateRule.swift
//  Atlas
//

import Foundation

/// A rule of Apple's an event's dates can break, for a new event (the New
/// Event sheet's words, `newEventText`) and an existing one (what's wrong
/// with its dates, `text`, and what to do, `fix`). The raw values are
/// `get_in_app_events`' names for them in `missingForReview`.
enum InAppEventDateRule: String, CaseIterable, Hashable, Sendable {
    case eventEndBeforeStart
    case eventTooShort
    case eventTooLong
    case publishStartAfterEventStart
    case publishStartTooEarly
    case eventStartPassed
    case publishStartPassed

    /// The rules `dates` breaks, in this order: how long the event lasts,
    /// when its card shows against its start, then (with `now`) a start or
    /// a card's date that isn't in the future. A card shown more than 14
    /// days early isn't named again when its date has passed, nor a
    /// card's date when the start itself has passed: one fix covers both.
    static func broken(by dates: InAppEventDates, now: Date?) -> [Self] {
        var rules: [Self] = []
        let duration = dates.duration
        if duration <= 0 {
            rules.append(.eventEndBeforeStart)
        } else if duration < InAppEventDates.shortestDuration {
            rules.append(.eventTooShort)
        } else if duration > InAppEventDates.longestDuration {
            rules.append(.eventTooLong)
        }
        let startPassed = now.map { dates.eventStart <= $0 } ?? false
        let publishPassed = now.map { dates.publishStart <= $0 } ?? false
        if dates.publishStart > dates.eventStart {
            rules.append(.publishStartAfterEventStart)
        } else if dates.leadTime > InAppEventDates.longestLeadTime, !publishPassed {
            rules.append(.publishStartTooEarly)
        }
        if startPassed {
            rules.append(.eventStartPassed)
        } else if publishPassed {
            rules.append(.publishStartPassed)
        }
        return rules
    }

    /// The date to change for it.
    var field: InAppEventDateField {
        switch self {
        case .publishStartAfterEventStart, .publishStartTooEarly, .publishStartPassed: .publishStart
        case .eventStartPassed: .eventStart
        case .eventEndBeforeStart, .eventTooShort, .eventTooLong: .eventEnd
        }
    }

    /// What's wrong, without the dates: "The card’s date has passed."
    var title: String {
        switch self {
        case .eventEndBeforeStart: String(localized: "The event doesn’t end after it starts.")
        case .eventTooShort: String(localized: "The event is shorter than 15 minutes.")
        case .eventTooLong: String(localized: "The event is longer than 31 days.")
        case .publishStartAfterEventStart: String(localized: "The card shows only after the event has started.")
        case .publishStartTooEarly: String(localized: "The card shows more than 14 days before the event starts.")
        case .eventStartPassed: String(localized: "The event’s start has passed: App Store Connect only takes dates in the future.")
        case .publishStartPassed: String(localized: "The card’s date has passed: App Store Connect only takes dates in the future.")
        }
    }

    /// What's wrong with an existing event's `dates`, in plain words: "The
    /// card was set to show from Nov 18, 9:00 PM, which has passed. App
    /// Store Connect only takes dates in the future."
    func text(_ dates: InAppEventDates, _ format: InAppEventDateText = .current) -> String {
        switch self {
        case .eventEndBeforeStart:
            return String(localized: "The event is set to end \(format.date(dates.eventEnd)), which isn’t after it starts (\(format.date(dates.eventStart))).")
        case .eventTooShort:
            let minutes = Int(dates.duration / 60)
            return String(localized: "The event lasts \(minutes) minutes. Apple’s shortest is 15 minutes.")
        case .eventTooLong:
            let days = Int((dates.duration / 86400).rounded(.up))
            return String(localized: "The event lasts \(days) days. Apple’s longest is 31 days.")
        case .publishStartAfterEventStart:
            return String(localized: """
            The card is set to show from \(format.date(dates.publishStart)), after the event starts (\(format.date(dates.eventStart))). \
            It has to show by the start.
            """)
        case .publishStartTooEarly:
            let days = Int((dates.leadTime / 86400).rounded(.up))
            return String(localized: "The card is set to show \(days) days before the event starts. Apple allows 14 days at most.")
        case .eventStartPassed:
            return String(localized: """
            The event was set to start \(format.date(dates.eventStart)), which has passed. App Store Connect only takes dates in the future.
            """)
        case .publishStartPassed:
            return String(localized: """
            The card was set to show from \(format.date(dates.publishStart)), which has passed. App Store Connect only takes dates in the \
            future.
            """)
        }
    }

    /// What to do: "Move “Shows from” later, e.g. to Nov 21, 3:00 PM.",
    /// with `suggestion` the "Shows from" that fixes it.
    func fix(suggestion: Date?, _ format: InAppEventDateText = .current) -> String {
        switch self {
        case .eventEndBeforeStart, .eventTooShort, .eventTooLong:
            return String(localized: "Set “Ends” to between 15 minutes and 31 days after “Starts”.")
        case .eventStartPassed:
            return String(localized: "Move “Starts” and “Ends” later, and “Shows from” with them.")
        case .publishStartAfterEventStart:
            guard let suggestion else { return String(localized: "Move “Shows from” to the start or before it.") }
            return String(localized: "Move “Shows from” earlier, e.g. to \(format.date(suggestion)).")
        case .publishStartTooEarly, .publishStartPassed:
            guard let suggestion else { return String(localized: "Move “Shows from” later, and the event with it if it starts too soon.") }
            return String(localized: "Move “Shows from” later, e.g. to \(format.date(suggestion)).")
        }
    }

    /// The New Event sheet's words.
    var newEventText: String {
        switch self {
        case .eventEndBeforeStart: String(localized: "The event has to end after it starts.")
        case .eventTooShort: String(localized: "An event has to last at least 15 minutes.")
        case .eventTooLong: String(localized: "An event can last 31 days at most. End it sooner or start it later.")
        case .publishStartAfterEventStart: String(localized: "The card can’t start showing after the event has started.")
        case .publishStartTooEarly: String(localized: "The card can show at most 14 days before the event starts. Show it from later.")
        case .eventStartPassed: String(localized: "The event has to start in the future. Move its dates later.")
        case .publishStartPassed: String(localized: "The card has to start showing in the future. Show it from later.")
        }
    }

    /// `get_in_app_events`' name for it.
    var mcpValue: String { rawValue }
}
