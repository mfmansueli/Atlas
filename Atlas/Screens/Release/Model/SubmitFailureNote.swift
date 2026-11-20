//
//  SubmitFailureNote.swift
//  Atlas
//

import Foundation

/// The last Submit that didn't go, as the Submit sheet says it, with when
/// it happened and, for a refusal only over In-App Event dates that had
/// passed, each event's dates then. Alba, Nov 19: the sheet kept "the card
/// was set to show from … which has passed" after the person had pushed
/// new dates for "7 Days of Gratitude". Once the events are read again,
/// such a refusal goes when every event it named has new dates, none of
/// them passed; anything else stays, marked as the last attempt's.
struct SubmitFailureNote: Hashable, Sendable {
    var text: String
    var date: Date
    /// For a refusal only over dates that had passed: the events it named,
    /// with every schedule's dates at the time (empty when one had none).
    /// Nil for any other failure.
    var pastDates: [InAppEvent.ID: [InAppEventDates]]?
    /// The events were read again since: the sheet says it's the last
    /// attempt's.
    var isFromLastAttempt = false

    /// `pastDateEventIDs` for a refusal only over dates that had passed,
    /// with `events` as they were then.
    init(text: String, date: Date, pastDateEventIDs: [InAppEvent.ID]? = nil, events: [InAppEvent] = []) {
        self.text = text
        self.date = date
        pastDates = pastDateEventIDs.map { ids in
            Dictionary(ids.map { id in (id, events.first { $0.id == id }?.everySchedulesDates ?? []) }) { first, _ in first }
        }
    }

    /// Whether `events`, read again, leave nothing of it: every event it
    /// named has other dates than then, none of them passed at `now` (or
    /// it's gone, or past App Review). Never for other failures.
    func isCleared(by events: [InAppEvent], now: Date) -> Bool {
        guard let pastDates, !pastDates.isEmpty else { return false }
        return pastDates.allSatisfy { id, before in
            guard let event = events.first(where: { $0.id == id }), event.state.isBeforeApproval else { return true }
            let passed = event.brokenDateRules(now: now)?.contains { $0 == .publishStartPassed || $0 == .eventStartPassed } ?? false
            return (event.everySchedulesDates ?? []) != before && !passed
        }
    }

    /// The text, after "From the last Submit (today at 7:37 PM):" once
    /// it's the last attempt's.
    func shownText(now: Date, format: InAppEventDateText = .current) -> String {
        guard isFromLastAttempt else { return text }
        return String(localized: "From the last Submit (\(format.dayAndTime(date, now: now))):") + "\n" + text
    }
}
