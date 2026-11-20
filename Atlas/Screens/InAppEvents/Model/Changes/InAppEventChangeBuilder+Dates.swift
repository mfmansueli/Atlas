//
//  InAppEventChangeBuilder+Dates.swift
//  Atlas
//

import Foundation

// An existing event's dates as one Review & Push change,
// `inAppEvents.<appID>.<eventID>.details.territorySchedules`: a
// `PATCH /v1/appEvents/{id}` with `territorySchedules` alone (Apple's
// `AppEventUpdateRequest`, API 4.6), every schedule with its own
// territories as App Store Connect has them and the new dates. Editing
// "Shows from", "Starts" or "Ends" again replaces it. Restorable, with a
// conflict check on the card's date. An assistant's dates for an event
// whose dates the person queued wait beside theirs as the change's
// alternative (`datesAlternative`), never over them. Atlas never guesses territories: an
// event whose schedules it read without them, or with different dates in
// different places, can't change here.
extension InAppEventChangeBuilder {
    static let schedulesAttribute = "territorySchedules"

    func datesChangeID(eventID: String) -> String {
        "\(idPrefix)\(eventID).\(Self.detailsSegment).\(Self.schedulesAttribute)"
    }

    /// Why Atlas can't change `event`'s dates, saying what to do; nil when
    /// it can.
    static func datesEditProblem(of event: InAppEvent) -> String? {
        let name = event.referenceName
        guard event.state.isEditable else {
            return String(localized: "“\(name)” is \(event.state.rawValue): only a draft, an event ready for review or a rejected one can change.")
        }
        guard !event.schedules.isEmpty, event.schedules.allSatisfy({ !$0.territories.isEmpty }) else {
            return String(localized: """
            Atlas doesn’t know which countries or regions “\(name)” shows in, so it can’t send new dates without changing those too. \
            Change its dates in App Store Connect.
            """)
        }
        let dates = event.schedules.map(InAppEventDates.init)
        guard dates.allSatisfy({ $0 != nil }) else {
            return String(localized: "“\(name)” has no dates in App Store Connect yet. Set them there first.")
        }
        guard Set(dates).count == 1 else {
            return String(localized: """
            “\(name)” has different dates in different countries or regions. Atlas changes one set for all of them, so change these \
            in App Store Connect.
            """)
        }
        return nil
    }

    /// The change that gives `event` the `dates`; nil when they're what
    /// App Store Connect has, or Atlas can't change them
    /// (`datesEditProblem`). Blocked while they break a rule at `now`.
    func datesChange(
        to dates: InAppEventDates, of event: InAppEvent, now: Date, source: ChangeSource, reason: String = "",
        format: InAppEventDateText = .current
    ) -> PendingChange? {
        guard Self.datesEditProblem(of: event) == nil, let old = event.dates, dates != old,
              let request = Self.datesRequest(eventID: event.id, schedules: event.schedules, dates: dates),
              let restore = Self.datesRequest(eventID: event.id, schedules: event.schedules, dates: old)
        else { return nil }
        let path = "/v1/\(Self.eventType)/\(event.id)"
        var change = PendingChange(
            id: datesChangeID(eventID: event.id),
            appID: appID, section: .inAppEvents, group: group(event), groupID: event.id,
            title: String(localized: "Dates"),
            oldValue: Self.datesText(old, format), newValue: Self.datesText(dates, format),
            source: source,
            blockedReason: dates.broken(now: now).first?.text(dates, format),
            requests: [request], restoreRequests: [restore],
            conflictCheck: ConflictCheck(
                path: "\(path)?fields[\(Self.eventType)]=\(Self.schedulesAttribute)",
                keyPath: ["data", "attributes", Self.schedulesAttribute, "0", InAppEventDateField.publishStart.rawValue],
                expected: AppStoreConnectDate.text(old.publishStart), format: .date
            )
        )
        let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { change.groupNote = note }
        if source.isAssistant {
            change.awaitingAcceptance = String(localized: "Look at it, then accept it here or on the event’s page.")
        }
        return change
    }

    /// The `PATCH` that writes `dates` into every one of `schedules`, each
    /// keeping its territories.
    static func datesRequest(eventID: String, schedules: [InAppEventSchedule], dates: InAppEventDates) -> PushRequest? {
        let written: [[String: Any]] = schedules.map { schedule in
            [
                "territories": schedule.territories,
                InAppEventDateField.publishStart.rawValue: AppStoreConnectDate.text(dates.publishStart),
                InAppEventDateField.eventStart.rawValue: AppStoreConnectDate.text(dates.eventStart),
                InAppEventDateField.eventEnd.rawValue: AppStoreConnectDate.text(dates.eventEnd),
            ]
        }
        let document: [String: Any] = ["data": ["type": eventType, "id": eventID, "attributes": [schedulesAttribute: written]]]
        guard let body = try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .withoutEscapingSlashes]) else { return nil }
        return PushRequest(method: .patch, path: "/v1/\(eventType)/\(eventID)", body: body)
    }

    /// An assistant's `dates` for an event whose dates the person already
    /// queued: kept beside the person's change as its alternative, so it
    /// overwrites nothing (Accept replaces theirs, Dismiss keeps theirs).
    /// Nil when Atlas can't change the event's dates.
    func datesAlternative(
        to dates: InAppEventDates, of event: InAppEvent, now: Date, source: ChangeSource, reason: String = "",
        format: InAppEventDateText = .current
    ) -> ChangeAlternative? {
        guard Self.datesEditProblem(of: event) == nil, let old = event.dates,
              let request = Self.datesRequest(eventID: event.id, schedules: event.schedules, dates: dates),
              let restore = Self.datesRequest(eventID: event.id, schedules: event.schedules, dates: old)
        else { return nil }
        let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return ChangeAlternative(
            newValue: Self.datesText(dates, format), source: source, requests: [request], restoreRequests: [restore],
            note: note.isEmpty ? nil : note, blockedReason: dates.broken(now: now).first?.text(dates, format)
        )
    }

    /// The dates an assistant suggests beside the person's queued ones,
    /// with who and why; nil when none waits.
    func suggestedDates(for eventID: String, in changes: [PendingChange]) -> (dates: InAppEventDates, alternative: ChangeAlternative)? {
        guard let alternative = queuedDates(for: eventID, in: changes)?.alternative, alternative.source.isAssistant,
              let dates = Self.datesValue(in: alternative.requests)
        else { return nil }
        return (dates, alternative)
    }

    /// The dates a dates change writes; nil when the change isn't one.
    static func datesValue(in change: PendingChange) -> InAppEventDates? {
        datesValue(in: change.requests)
    }

    /// The dates the first of `requests` writes; nil when it isn't a
    /// dates `PATCH`.
    static func datesValue(in requests: [PushRequest]) -> InAppEventDates? {
        guard let request = requests.first, request.method == .patch, request.path.hasPrefix("/v1/\(eventType)/"),
              let object = request.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let attributes = (object["data"] as? [String: Any])?["attributes"] as? [String: Any],
              let schedule = (attributes[schedulesAttribute] as? [[String: Any]])?.first
        else { return nil }
        func date(_ field: InAppEventDateField) -> Date? { AppStoreConnectDate.date(schedule[field.rawValue] as? String) }
        guard let publish = date(.publishStart), let start = date(.eventStart), let end = date(.eventEnd) else { return nil }
        return InAppEventDates(publishStart: publish, eventStart: start, eventEnd: end)
    }

    /// The dates change waiting for `eventID`.
    func queuedDates(for eventID: String, in changes: [PendingChange]) -> PendingChange? {
        let id = datesChangeID(eventID: eventID)
        return changes.first { $0.id == id && owns($0) }
    }

    /// The dates as they will be once pushed: what's queued, else App
    /// Store Connect's.
    func dates(of event: InAppEvent, in changes: [PendingChange]) -> InAppEventDates? {
        queuedDates(for: event.id, in: changes).flatMap(Self.datesValue) ?? event.dates
    }

    /// "Shows from Nov 21, 3:00 PM", "Starts …", "Ends …", one per line.
    static func datesText(_ dates: InAppEventDates, _ format: InAppEventDateText = .current) -> String {
        InAppEventDateField.allCases.map { "\($0.title) \(format.date(dates[$0]))" }.joined(separator: "\n")
    }
}
