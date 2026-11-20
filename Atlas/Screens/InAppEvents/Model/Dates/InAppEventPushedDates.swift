//
//  InAppEventPushedDates.swift
//  Atlas
//

import Foundation

/// Dates a push wrote a moment ago that a read doesn't show yet. App Store
/// Connect can answer with an event's old schedule for a short while after
/// the `PATCH` went (Alba, Nov 19: new dates pushed with no failures, the
/// Submit sheet still asked to fix the old ones, and a little later all
/// was well). For `window` after the push, a read with other dates gets
/// the pushed ones, so nothing asks to fix dates the person just fixed;
/// one more read once the window ends tells which App Store Connect
/// kept.
@MainActor
struct InAppEventPushedDates {
    static let window: TimeInterval = 120

    let appID: StoreApp.ID
    let history: PushHistory?
    let now: Date

    /// `events` with any dates pushed within the window put over a read
    /// that doesn't have them yet, every schedule keeping its territories,
    /// and when to read again (nil when no read is behind).
    func settle(_ events: [InAppEvent]) -> (events: [InAppEvent], readAgainAt: Date?) {
        guard let history else { return (events, nil) }
        let records = history.records(for: appID).filter { $0.date <= now && now.timeIntervalSince($0.date) < Self.window }
        guard !records.isEmpty else { return (events, nil) }
        let builder = InAppEventChangeBuilder(appID: appID)
        var readAgainAt: Date?
        let settled = events.map { event in
            let id = builder.datesChangeID(eventID: event.id)
            // The newest push of this event's dates wins.
            guard let record = records.first(where: { $0.pushed.contains { $0.id == id } }),
                  let change = record.pushed.first(where: { $0.id == id }),
                  let pushed = InAppEventChangeBuilder.datesValue(in: change),
                  !Self.shows(pushed, event)
            else { return event }
            let end = record.date.addingTimeInterval(Self.window)
            readAgainAt = min(readAgainAt ?? end, end)
            var event = event
            for index in event.schedules.indices {
                event.schedules[index].publishStart = pushed.publishStart
                event.schedules[index].eventStart = pushed.eventStart
                event.schedules[index].eventEnd = pushed.eventEnd
            }
            return event
        }
        return (settled, readAgainAt)
    }

    /// Whether every schedule of `event` has `dates` already (to the
    /// second: App Store Connect writes them back in its own format).
    nonisolated static func shows(_ dates: InAppEventDates, _ event: InAppEvent) -> Bool {
        guard let all = event.everySchedulesDates else { return false }
        return all.allSatisfy { read in
            InAppEventDateField.allCases.allSatisfy { abs(read[$0].timeIntervalSince(dates[$0])) < 1 }
        }
    }
}
