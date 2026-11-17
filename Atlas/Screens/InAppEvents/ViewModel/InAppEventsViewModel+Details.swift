//
//  InAppEventsViewModel+Details.swift
//  Atlas
//

import Foundation

// What the editor shows around the texts: the event's settings, its
// images, how it did, and the footer's one action.
extension InAppEventsViewModel {
    /// Badge, dates, where it shows, purpose and priority, as rows.
    func settings(of event: InAppEvent) -> [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []
        rows.append((String(localized: "Badge"), event.badge?.title ?? String(localized: "None")))
        rows.append((String(localized: "Event dates"), event.schedule?.eventStart == nil
                ? event.datesText
                : String(localized: "\(event.datesText), in each country’s time zone")))
        rows.append((String(localized: "On the App Store"), Self.publishText(event)))
        rows.append((String(localized: "Countries and regions"), Self.territoriesText(event)))
        if let purpose = event.purpose { rows.append((String(localized: "Purpose"), purpose.title(appName: app.name))) }
        rows.append((String(localized: "Priority"), event.priority.title))
        return rows
    }

    /// "Shows on the App Store from Nov 24", "Ended Nov 7".
    static func publishText(_ event: InAppEvent) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        if event.state.isOver, let end = event.schedule?.eventEnd { return String(localized: "Ended \(end.formatted(style))") }
        guard let start = event.schedule?.publishStart else { return String(localized: "Not scheduled yet") }
        return String(localized: "Shows on the App Store from \(start.formatted(style))")
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
                ? String(localized: "Submitted with \(version). Changes now wait for the next review.")
                : String(localized: "Goes to App Review with \(version).")
        case .waitingForReview, .inReview, .approved, .live:
            return String(localized: "With App Review or on the App Store. Changes now wait for the next review.")
        case .ended, .archived:
            return String(localized: "Duplicate it to run it again next year.")
        case .draft, .rejected:
            var missing = event.missing
            if suggestedCount > 0, let index = missing.firstIndex(of: String(localized: "write every language")) {
                missing[index] = String(localized: "accept or write every language")
            }
            if pendingCount > 0 { missing.append(String(localized: "push its changes")) }
            guard !missing.isEmpty else { return String(localized: "Ready. Events can go to App Review on their own.") }
            return String(localized: "To submit: \(missing.formatted(.list(type: .and))). Events can go to App Review on their own.")
        }
    }

    /// The footer's button: what it says and whether it can be pressed.
    var footerButton: (title: String, isEnabled: Bool)? {
        guard let event = selectedEvent else { return nil }
        switch status(of: event) {
        case .goesWithVersion: return (String(localized: "Open Submission"), true)
        case .ended, .archived: return (String(localized: "Duplicate Event"), true)
        case .draft, .rejected: return (String(localized: "Submit Event…"), event.canSubmit && pendingCount == 0 && !isSubmitting)
        case .waitingForReview, .inReview, .approved, .live: return nil
        }
    }

    /// Sends the selected event to App Review on its own.
    func submitSelectedEvent(using release: any ReleaseServices, platform: String?) async {
        guard let event = selectedEvent, event.canSubmit, !isSubmitting else { return }
        isSubmitting = true
        actionError = nil
        defer { isSubmitting = false }
        do {
            try await release.submitEvents([event.id], for: app, platform: platform)
            toast = ToastMessage(text: String(localized: "“\(ReleaseViewModel.displayName(of: event))” is submitted. App Review usually takes about a day."))
            undo = nil
            await load(force: true)
        } catch {
            actionError = error.localizedDescription
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
            text: String(localized: "“\(event.trimmedReferenceName)” waits in Review & Push. It’s created as a draft when you push."),
            actionTitle: String(localized: "Review & Push")
        )
        return true
    }

    /// New events waiting in Review & Push, by their reference line.
    var queuedNewEvents: [PendingChange] {
        queue.changes(for: app.id, section: .inAppEvents).filter(builder.isNewEvent)
    }
}
