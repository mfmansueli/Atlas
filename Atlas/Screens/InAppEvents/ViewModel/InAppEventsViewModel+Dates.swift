//
//  InAppEventsViewModel+Dates.swift
//  Atlas
//

import Foundation

// A draft's dates on its page ("Shows from", "Starts", "Ends"), edited
// like its details: one change in Review & Push that every edit replaces,
// checked against Apple's rules at the view model's clock, with an undo
// per date; an assistant's dates beside the person's own, to accept or
// dismiss. And the New Event sheet's warnings about App Review's time.
extension InAppEventsViewModel {
    /// The dates change waiting for `event`.
    func queuedDates(of event: InAppEvent) -> PendingChange? {
        queue.change(id: builder.datesChangeID(eventID: event.id))
    }

    /// The dates as they will be: what's queued, else App Store Connect's.
    func dates(of event: InAppEvent) -> InAppEventDates? {
        queuedDates(of: event).flatMap(InAppEventChangeBuilder.datesValue) ?? event.dates
    }

    /// Why the dates can't change here; nil when they can.
    func datesEditProblem(of event: InAppEvent) -> String? {
        InAppEventChangeBuilder.datesEditProblem(of: event)
    }

    /// The person changed one date: queued with the others as they will
    /// be; back to App Store Connect's dates, the change leaves the queue.
    func setDate(_ field: InAppEventDateField, to date: Date, of event: InAppEvent) {
        guard datesEditProblem(of: event) == nil, var dates = dates(of: event), dates[field] != date else { return }
        dates[field] = date
        setDates(dates, of: event)
    }

    /// Queues `dates` as the person's, or takes the change out when
    /// they're App Store Connect's.
    func setDates(_ dates: InAppEventDates, of event: InAppEvent) {
        guard datesEditProblem(of: event) == nil else { return }
        if let change = builder.datesChange(to: dates, of: event, now: now(), source: .you) {
            queue.upsert(change)
        } else {
            queue.discard(id: builder.datesChangeID(eventID: event.id))
        }
    }

    /// Undo on one date's row: App Store Connect's date again, the others
    /// as they are.
    func revertDate(_ field: InAppEventDateField, of event: InAppEvent) {
        guard var dates = dates(of: event), let live = event.dates else {
            revertDates(of: event)
            return
        }
        dates[field] = live[field]
        setDates(dates, of: event)
    }

    /// Dismiss on an assistant's dates: App Store Connect's again.
    func revertDates(of event: InAppEvent) {
        queue.discard(id: builder.datesChangeID(eventID: event.id))
    }

    /// Accept on an assistant's dates: they wait like the person's own.
    func acceptDates(of event: InAppEvent) {
        queue.accept(id: builder.datesChangeID(eventID: event.id))
    }

    /// An assistant's dates waiting beside the ones the person queued,
    /// with who suggested them and why.
    func suggestedDates(of event: InAppEvent) -> (dates: InAppEventDates, alternative: ChangeAlternative)? {
        builder.suggestedDates(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents))
    }

    /// Accept on the assistant's dates beside the person's: they replace
    /// theirs in Review & Push.
    func acceptSuggestedDates(of event: InAppEvent) {
        queue.resolveAlternative(id: builder.datesChangeID(eventID: event.id), keepAlternative: true)
    }

    /// Dismiss on them: the person's dates stay.
    func dismissSuggestedDates(of event: InAppEvent) {
        queue.resolveAlternative(id: builder.datesChangeID(eventID: event.id), keepAlternative: false)
    }

    /// Whether `field` waits in Review & Push with another date than App
    /// Store Connect's.
    func isDatePending(_ field: InAppEventDateField, of event: InAppEvent) -> Bool {
        guard let queued = queuedDates(of: event).flatMap(InAppEventChangeBuilder.datesValue) else { return false }
        return queued[field] != event.dates?[field]
    }

    /// What's wrong with the dates the event will have, at the clock, in
    /// plain words with the fix.
    func dateProblems(of event: InAppEvent, format: InAppEventDateText = .current) -> [String] {
        guard event.state.isEditable, let dates = dates(of: event) else { return [] }
        return dates.broken(now: now()).map { rule in
            let suggestion = rule.field == .publishStart ? dates.suggestedPublishStart(now: now(), calendar: format.calendar) : nil
            return "\(rule.text(dates, format)) \(rule.fix(suggestion: suggestion, format))"
        }
    }

    /// The "Shows from" that fixes the card's date, when it's the one to
    /// change (it has passed, or breaks the 14 days).
    func suggestedPublishStart(of event: InAppEvent, format: InAppEventDateText = .current) -> Date? {
        guard event.state.isEditable, let dates = dates(of: event),
              dates.broken(now: now()).contains(where: { $0.field == .publishStart })
        else { return nil }
        return dates.suggestedPublishStart(now: now(), calendar: format.calendar)
    }

    /// A fix's button: its dates queued as the person's.
    func applySuggestedDates(_ suggested: [InAppEventDateField: Date], of event: InAppEvent) {
        guard var dates = dates(of: event), !suggested.isEmpty else { return }
        for (field, date) in suggested {
            dates[field] = date
        }
        setDates(dates, of: event)
    }

    /// "Show from Nov 21, 3:00 PM": a fix's button.
    static func showFromTitle(_ date: Date, format: InAppEventDateText = .current) -> String {
        String(localized: "Show from \(format.date(date))")
    }

    // MARK: - New Event

    /// The New Event sheet's warnings about App Review's time.
    func warnings(for event: NewInAppEvent) -> [String] {
        event.warnings(now: now())
    }
}
