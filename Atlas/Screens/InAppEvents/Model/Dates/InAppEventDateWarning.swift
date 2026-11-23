//
//  InAppEventDateWarning.swift
//  Atlas
//

import Foundation

/// What App Review's time may do to an event's dates: it usually takes
/// up to two days, an event shows only once it's approved, then it follows
/// its schedule. Apple sets no shortest notice, so these warn and never
/// block. The raw values are `get_in_app_events`' names for them in
/// `reviewWarnings`.
enum InAppEventDateWarning: String, CaseIterable, Hashable, Sendable {
    /// The card is set to show within two days: it may show later.
    case cardShowsSoon
    /// The event starts within two days: it may start before it's
    /// approved, and its card would miss some of it. Said instead of
    /// `cardShowsSoon`, which it includes.
    case eventStartsSoon

    static func warnings(for dates: InAppEventDates, now: Date) -> [Self] {
        let startsIn = dates.eventStart.timeIntervalSince(now)
        if startsIn > 0, startsIn < InAppEventDates.reviewTime { return [.eventStartsSoon] }
        let showsIn = dates.publishStart.timeIntervalSince(now)
        if showsIn > 0, showsIn < InAppEventDates.reviewTime, dates.publishStart <= dates.eventStart { return [.cardShowsSoon] }
        return []
    }

    /// The date it's about.
    var field: InAppEventDateField {
        switch self {
        case .cardShowsSoon: .publishStart
        case .eventStartsSoon: .eventStart
        }
    }

    /// "The card is set to show in 20 hours. App Review usually takes up
    /// to 2 days, …".
    func text(_ dates: InAppEventDates, now: Date, _ format: InAppEventDateText = .current) -> String {
        switch self {
        case .cardShowsSoon:
            String(localized: """
            The card is set to show \(format.timeUntil(dates.publishStart, from: now)). App Review usually takes up to 2 days, \
            so the card may show later than planned.
            """)
        case .eventStartsSoon:
            String(localized: """
            The event starts \(format.timeUntil(dates.eventStart, from: now)). App Review usually takes up to 2 days, so the \
            card may miss part of the event.
            """)
        }
    }

    /// What to do about it, with `suggestion` a later "Shows from".
    func fix(suggestion: Date?, _ format: InAppEventDateText = .current) -> String {
        switch self {
        case .cardShowsSoon:
            guard let suggestion else { return String(localized: "Submit it soon, or move the event later.") }
            return String(localized: "To give App Review 2 days, move “Shows from” to \(format.date(suggestion)).")
        case .eventStartsSoon:
            return String(localized: "To give App Review 2 days, move “Starts” and “Ends” later, or submit it now and expect it to show late.")
        }
    }

    var mcpValue: String { rawValue }
}
