//
//  InAppEventsViewModel+Details.swift
//  Atlas
//

import Foundation

// What the event's page shows around the texts: the event's settings, its
// images, how it did, the line at the bottom and the header's one action.
extension InAppEventsViewModel {
    /// Badge, dates and where it shows, as rows, at the view model's
    /// clock: a date that has passed before approval says so, with Fix…
    /// on it while the event can change. The deep link, purpose, priority
    /// and primary language are in the details card, to edit, and so are
    /// a draft's dates.
    func settings(of event: InAppEvent, format: InAppEventDateText = .current) -> [InAppEventSettingsRow] {
        let now = now()
        let canFix = event.state.isEditable && InAppEventChangeBuilder.datesEditProblem(of: event) == nil
        let queued = builder.queuedDates(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents))
        let fixedByQueued = queued.flatMap(InAppEventChangeBuilder.datesValue).map { $0.broken(now: now).isEmpty } ?? false
        var rows: [InAppEventSettingsRow] = []
        rows.append(InAppEventSettingsRow(title: String(localized: "Badge"), value: event.badge?.title ?? String(localized: "None"), key: "badge"))
        var dates = InAppEventSettingsRow(
            title: String(localized: "Event dates"),
            value: event.schedule?.eventStart == nil ? event.datesText : String(localized: "\(event.datesText), in each country’s time zone"),
            key: "dates"
        )
        if event.state.isBeforeApproval, let start = Self.passed(.eventStart, of: event, now: now) {
            dates.value = String(localized: "Start time \(format.dayAndTime(start, now: now)) (your time) has passed")
            Self.markPassed(&dates, field: .eventStart, canFix: canFix, fixedByQueued: fixedByQueued)
        }
        rows.append(dates)
        var publish = InAppEventSettingsRow(
            title: String(localized: "On the App Store"), value: Self.publishText(event, now: now, format: format), key: "publish"
        )
        if event.state.isBeforeApproval, Self.passed(.publishStart, of: event, now: now) != nil {
            Self.markPassed(&publish, field: .publishStart, canFix: canFix, fixedByQueued: fixedByQueued)
        }
        rows.append(publish)
        rows.append(InAppEventSettingsRow(title: String(localized: "Countries and regions"), value: Self.territoriesText(event), key: "territories"))
        return rows
    }

    /// The earliest of `field`'s dates in any schedule, when it has passed
    /// at `now`: App Store Connect refuses the event for any of them.
    static func passed(_ field: InAppEventDateField, of event: InAppEvent, now: Date) -> Date? {
        let dates = event.schedules.compactMap { schedule -> Date? in
            switch field {
            case .publishStart: schedule.publishStart
            case .eventStart: schedule.eventStart
            case .eventEnd: schedule.eventEnd
            }
        }
        return dates.filter { $0 <= now }.min()
    }

    /// A row whose date has passed: a problem with Fix…, or calm once new
    /// dates wait in Review & Push.
    private static func markPassed(_ row: inout InAppEventSettingsRow, field: InAppEventDateField, canFix: Bool, fixedByQueued: Bool) {
        guard !fixedByQueued else {
            row.value += String(localized: ". New dates wait in Review & Push.")
            return
        }
        row.isProblem = true
        if canFix { row.fixField = field }
    }

    /// "Shows on the App Store from Nov 24", "Shows on the App Store from
    /// today at 3:00 PM" on its own day, "Ended Nov 7"; before approval, a
    /// time that has passed: "Was set to show from Nov 19 at 12:00 AM (your
    /// time), which has passed".
    static func publishText(_ event: InAppEvent, now: Date, format: InAppEventDateText = .current) -> String {
        if event.state.isOver, let end = event.schedule?.eventEnd { return String(localized: "Ended \(format.day(end))") }
        guard let start = event.schedule?.publishStart else { return String(localized: "Not scheduled yet") }
        if event.state.isBeforeApproval, let passed = passed(.publishStart, of: event, now: now) {
            return String(localized: "Show time \(format.dayAndTime(passed, now: now)) (your time) has passed")
        }
        if format.calendar.isDate(start, inSameDayAs: now) {
            return String(localized: "Shows on the App Store from today at \(format.time(start))")
        }
        return String(localized: "Shows on the App Store from \(format.day(start))")
    }

    static func territoriesText(_ event: InAppEvent) -> String {
        let count = event.schedule?.territories.count ?? 0
        return count == 0 || count >= TerritoryCatalog.standard.count ? String(localized: "All \(TerritoryCatalog.standard.count)") : "\(count)"
    }

    /// "1920 × 1080 · for every language", or "Missing · needed to submit".
    static func mediaText(_ kind: InAppEventMedia.Kind, of event: InAppEvent) -> String {
        guard let media = event.media(kind) else { return String(localized: "Missing · needed to submit") }
        let what = media.isVideo ? String(localized: "Video") : media.sizeText ?? String(localized: "Image")
        return String(localized: "\(what) · for every language")
    }

    // MARK: - Footer

    /// Changes of the selected event waiting in Review & Push.
    var pendingCount: Int {
        guard let event = selectedEvent else { return 0 }
        let prefix = "\(builder.idPrefix)\(event.id)."
        return queue.changes(for: app.id, section: .inAppEvents).count { $0.id.hasPrefix(prefix) }
    }

    /// The footer's line under the editor.
    var footerText: String {
        guard let event = selectedEvent else { return "" }
        switch status(of: event) {
        case let .goesWithVersion(version):
            return event.state.isSubmitted
                ? String(localized: "Submitted with \(version). Changes wait for next review.")
                : String(localized: "Goes to App Review with \(version).")
        case .waitingForReview, .inReview, .approved, .live:
            return String(localized: "In review or live. Changes wait for the next review.")
        case .ended, .archived:
            return String(localized: "Duplicate it to run it again next year.")
        case .draft, .rejected:
            // What waits in Review & Push counts as there; never "Ready"
            // while the "Before App Review" list has a need open.
            var missing = reviewItems(of: event).filter { $0.state != .queued }.map { item in
                switch item.kind {
                case let .need(need):
                    item.state == .suggested ? String(localized: "accept or \(need.footerText)") : need.footerText
                case .linkNotClaimed:
                    String(localized: "make \(app.name) open its deep link")
                }
            }
            if pendingCount > 0 { missing.append(String(localized: "push its changes")) }
            guard !missing.isEmpty else { return String(localized: "Ready. Submit it without a new version.") }
            return String(localized: "To submit: \(missing.formatted(.list(type: .and))). No new version needed.")
        }
    }

    /// The footer's button: what it says and whether it can be pressed.
    var footerButton: (title: String, isEnabled: Bool)? {
        guard let event = selectedEvent else { return nil }
        switch status(of: event) {
        case .goesWithVersion: return (String(localized: "Open Submission"), true)
        case .ended, .archived: return (String(localized: "Duplicate Event"), true)
        case .draft, .rejected: return (String(localized: "Submit Event…"), canSubmitOnItsOwn(event) && pendingCount == 0 && !isSubmitting)
        case .waitingForReview, .inReview, .approved, .live: return nil
        }
    }

    /// Everything App Review needs, and a deep link the app's project
    /// claims (or one Atlas can't check).
    func canSubmitOnItsOwn(_ event: InAppEvent) -> Bool {
        event.canSubmit(now: now()) && !linkClaim(of: event).blocksSubmit
    }

    /// Sends the selected event to App Review on its own.
    func submitSelectedEvent(using release: any ReleaseServices, platform: String?) async {
        guard let event = selectedEvent, canSubmitOnItsOwn(event), !isSubmitting else { return }
        isSubmitting = true
        actionError = nil
        defer { isSubmitting = false }
        do {
            try await release.submitEvents([event.id], for: app, platform: platform)
            InAppEventSubmitSuggestionStore.shared.remove(for: app.id, eventID: event.id)
            toast = ToastMessage(text: String(localized: "“\(ReleaseViewModel.displayName(of: event))” submitted. App Review usually takes a day."))
            undo = nil
            await load(force: true)
        } catch {
            actionError = AppleErrorCopy(String(localized: "The event wasn’t submitted.", comment: "kind:error"), error: error).text
        }
    }

    /// Duplicate Event: a new draft with every language's texts, starting
    /// a year after the original (or as many years as it takes to start in
    /// the future), waiting in Review & Push.
    func duplicateSelectedEvent() {
        guard let event = selectedEvent else { return }
        var copy = NewInAppEvent(now: now())
        copy.referenceName = copyName(of: event)
        copy.badge = event.badge ?? .specialEvent
        copy.purpose = event.purpose ?? .appropriateForAllUsers
        copy.priority = event.priority
        copy.purchaseRequirement = event.purchaseRequirement ?? copy.purchaseRequirement
        copy.deepLink = event.deepLink ?? ""
        copy.primaryLocale = event.primaryLocale ?? copy.primaryLocale
        let calendar = Calendar.current
        if let schedule = event.schedule, let start = schedule.eventStart, let end = schedule.eventEnd {
            var years = 1
            while let moved = calendar.date(byAdding: .year, value: years, to: start), moved <= now(), years < 100 { years += 1 }
            copy.eventStart = calendar.date(byAdding: .year, value: years, to: start) ?? copy.eventStart
            copy.eventEnd = calendar.date(byAdding: .year, value: years, to: end) ?? copy.eventEnd
            copy.publishStart = schedule.publishStart.flatMap { calendar.date(byAdding: .year, value: years, to: $0) } ?? copy.publishStart
            // A card's date that has passed while the start hasn't: the
            // earliest one App Store Connect takes.
            if copy.publishStart <= now(), let publish = copy.dates.suggestedPublishStart(now: now(), calendar: calendar) {
                copy.publishStart = publish
            }
        }
        for localization in event.localizations {
            copy.texts[localization.locale] = Dictionary(uniqueKeysWithValues: InAppEventField.allCases.map { ($0, localization.text($0)) })
        }
        add(copy)
    }

    /// "Gratitude Week copy", or "Gratitude Week copy 2" when that's taken.
    private func copyName(of event: InAppEvent) -> String {
        let taken = Set(takenReferenceNames().map(NewInAppEvent.nameKey))
        let base = String(localized: "\(event.referenceName) copy")
        var name = String(base.prefix(NewInAppEvent.referenceNameLimit))
        var number = 2
        while taken.contains(NewInAppEvent.nameKey(name)) {
            let suffix = " \(number)"
            name = String(base.prefix(NewInAppEvent.referenceNameLimit - suffix.count)) + suffix
            number += 1
        }
        return name
    }

    /// The reference names a new event can't take: the app's events' and
    /// the new ones' waiting in Review & Push.
    func takenReferenceNames() -> Set<String> {
        builder.takenReferenceNames(events: events, changes: queue.changes(for: app.id, section: .inAppEvents))
    }

    /// Why `event` can't be queued: what it says itself, a start that isn't
    /// in the future, or a reference name another event has. Nil when it
    /// can be.
    func problem(for event: NewInAppEvent) -> String? {
        event.problems(now: now(), takenReferenceNames: takenReferenceNames()).first
    }

    /// Queues a new event. Returns whether it was queued.
    @discardableResult
    func add(_ event: NewInAppEvent) -> Bool {
        guard problem(for: event) == nil, let change = builder.newEventChange(event) else { return false }
        queue.upsert(change)
        undo = nil
        toast = ToastMessage(
            text: String(localized: "Pushing creates “\(event.trimmedReferenceName)” as a draft."),
            actionTitle: String(localized: "Review & Push")
        )
        return true
    }

    /// New events waiting in Review & Push, by their reference line.
    var queuedNewEvents: [PendingChange] {
        queue.changes(for: app.id, section: .inAppEvents).filter(builder.isNewEvent)
    }
}
