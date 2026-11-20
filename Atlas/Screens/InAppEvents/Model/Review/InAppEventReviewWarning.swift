//
//  InAppEventReviewWarning.swift
//  Atlas
//

import Foundation

/// A warning in an event's "Before App Review" list, the Submit sheet and
/// `get_in_app_events`' `reviewWarnings`: App Review may not approve the
/// event before its card or its start (`InAppEventDateWarning`). It never
/// blocks Submit.
struct InAppEventReviewWarning: Identifiable, Hashable, Sendable {
    var warning: InAppEventDateWarning
    var text: String
    var detail: String?
    /// A later "Shows from" that gives App Review its two days.
    var suggestedDates: [InAppEventDateField: Date] = [:]

    var id: String { warning.rawValue }

    var mcpValue: String { warning.rawValue }

    /// The warnings of `dates` at `now`.
    static func warnings(for dates: InAppEventDates, now: Date, format: InAppEventDateText = .current) -> [Self] {
        dates.warnings(now: now).map { warning in
            var suggestion: Date?
            if warning == .cardShowsSoon, let later = dates.suggestedPublishStart(now: now, calendar: format.calendar), later > dates.publishStart {
                suggestion = later
            }
            var item = Self(warning: warning, text: warning.text(dates, now: now, format), detail: warning.fix(suggestion: suggestion, format))
            if let suggestion { item.suggestedDates = [.publishStart: suggestion] }
            return item
        }
    }

    /// The warnings of an event that's still editable, with the dates it
    /// will have once pushed (`queued`, else App Store Connect's).
    static func warnings(
        for event: InAppEvent, queued: PendingChange?, now: Date, format: InAppEventDateText = .current
    ) -> [Self] {
        guard event.state.isEditable, let dates = queued.flatMap(InAppEventChangeBuilder.datesValue) ?? event.dates else { return [] }
        return warnings(for: dates, now: now, format: format)
    }
}
