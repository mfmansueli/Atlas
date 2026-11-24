//
//  ReleaseViewModel+Events.swift
//  Atlas
//

import Foundation

// The Submit sheet's In-App Events: every draft that could go with the
// version, what each ticked one still needs (Submit stays off until it's
// fixed or unticked), the check of its deep link, and what a refused
// submission left in App Store Connect.
extension ReleaseViewModel {
    /// Drafts (and events ready for review or rejected) that haven't
    /// ended: ticked, each goes to App Review with the version once it has
    /// what App Store Connect needs.
    var offeredEvents: [InAppEvent] {
        Self.offeredEvents(in: events, now: now())
    }

    /// The events among `events` that could go with the version at `now`.
    static func offeredEvents(in events: [InAppEvent], now: Date) -> [InAppEvent] {
        events.filter { event in
            event.state.isEditable && (event.schedule?.eventEnd.map { $0 > now } ?? true)
        }
    }

    /// The ticked events among the offered ones, in the list's order.
    var tickedEvents: [InAppEvent] {
        offeredEvents.filter { options.eventIDs.contains($0.id) }
    }

    /// The deep link `event` will have once pushed.
    func eventDeepLink(of event: InAppEvent) -> String? {
        InAppEventChangeBuilder(appID: app.id).value(.deepLink, of: event, in: queue.changes(for: app.id, section: .inAppEvents))
    }

    /// Whether the app's project claims that deep link.
    func eventLinkClaim(of event: InAppEvent) -> InAppEventLinkClaim {
        InAppEventLinkClaim.of(eventDeepLink(of: event), in: linkClaims.state(for: app.id))
    }

    /// What the sheet says under `event`, at the clock: a date that has
    /// passed since the sheet opened blocks it too.
    func preflight(of event: InAppEvent, format: InAppEventDateText = .current) -> EventSubmitPreflight {
        let builder = InAppEventChangeBuilder(appID: app.id)
        let changes = queue.changes(for: app.id, section: .inAppEvents)
        let deepLink = eventDeepLink(of: event)
        let claim = eventLinkClaim(of: event)
        let now = now()
        let items = InAppEventReviewItem.items(for: event, changes: changes, builder: builder, claim: claim, appName: app.name, now: now, format: format)
        let report = eventsStore.deepLinkReport(for: app.id, eventID: event.id, deepLink: deepLink)
        // Dates waiting in Review & Push count once they're pushed first.
        let queuedDates = options.pushesChanges ? builder.queuedDates(for: event.id, in: changes) : nil
        return EventSubmitPreflight.check(
            event, items: items, link: (claim, report), builds: (selectedBuild, status?.builds ?? []), pushesChanges: options.pushesChanges,
            appName: app.name, reviewTime: InAppEventReviewWarning.warnings(for: event, queued: queuedDates, now: now, format: format),
            dates: options.pushesChanges ? builder.dates(of: event, in: changes) : event.dates, format: format
        )
    }

    /// The footer's words for ticked events that can't go: "fix or untick
    /// “Holidays 2026”", "fix or untick 3 events".
    var eventBlockers: [String] {
        let blocked = tickedEvents.filter { preflight(of: $0).blocks }
        switch blocked.count {
        case 0: return []
        case 1: return [String(localized: "fix or untick “\(Self.displayName(of: blocked[0]))”")]
        default: return [String(localized: "fix or untick \(blocked.count) In-App Events")]
        }
    }

    /// "Use Build 21": the build where the app opens the events' links.
    func useBuild(_ build: ReleaseBuild) {
        guard build.isSelectable else { return }
        options.buildID = build.id
        if let known = knownEncryption { options.encryption = known }
    }

    // MARK: - A refused submission

    /// What the sheet says when App Store Connect refused a step: what it
    /// refused, naming the event (“Holidays 2026”) for its reasons, and
    /// what it left: a draft review submission with the version and the
    /// events added, which Submit sends again.
    static func failureText(
        _ failure: SubmissionFailure, events: [InAppEvent], plan: SubmissionPlan, versionString: String, now: Date = .now,
        format: InAppEventDateText = .current
    ) -> String {
        let named = Self.namingEvents(in: failure.message, events: events)
        func name(_ id: String) -> String {
            events.first { $0.id == id }.map { String(localized: "“\(displayName(of: $0))”", comment: "kind:error") } ?? String(localized: "an In-App Event")
        }
        var lines: [String] = []
        switch failure.step {
        case .attachBuild:
            lines.append(String(localized: "App Store Connect didn’t take the build for \(versionString). \(named)"))
        case .encryption, .release, .phasedRelease, .createSubmission, .addVersion:
            lines.append(named)
        case let .addEvent(id):
            lines.append(String(localized: "App Store Connect didn’t add the In-App Event \(name(id)) to the submission. \(named)"))
        case let .removeEvent(id):
            lines.append(String(localized: "App Store Connect didn’t take the In-App Event \(name(id)) out of the submission. \(named)"))
        case .send:
            lines.append(String(localized: "App Store Connect didn’t send the submission to App Review. \(named)"))
            let withoutLink = plan.eventIDs.compactMap { id in events.first { $0.id == id } }
                .filter { InAppEventDetail.deepLink.value(in: $0) == nil }
            if failure.message.contains("'deepLink'"), !failure.message.contains(AppStoreConnectError.eventMarker), !withoutLink.isEmpty {
                let names = withoutLink.map { String(localized: "“\(displayName(of: $0))”", comment: "kind:error") }.formatted(.list(type: .and))
                lines.append(String(localized: "Without a deep link: \(names)."))
            }
        }
        lines += pastDateLines(failure, events: events, plan: plan, now: now, format: format)
        if failure.submissionID != nil {
            var carried: [String] = []
            if failure.hasVersion { carried.append(versionString) }
            carried += failure.eventIDs.map(name)
            let what = carried.isEmpty ? "" : String(localized: " with \(carried.formatted(.list(type: .and)))")
            lines.append(String(localized: """
            Nothing went to App Review. The submission stays a draft\(what). Fix what it names or untick the event, then \
            Submit again.
            """))
        } else {
            lines.append(String(localized: "Nothing went to App Review."))
        }
        return lines.joined(separator: "\n")
    }

    /// App Store Connect's "Supplied date must be in the future" for an
    /// event, as the date it is, when Atlas can tell: "“7 Days of
    /// Gratitude”: the card was set to show from Nov 18, 9:00 PM, which has
    /// passed. …". The event the step added, else the ones its reasons
    /// name, else the plan's.
    static func pastDateLines(
        _ failure: SubmissionFailure, events: [InAppEvent], plan: SubmissionPlan, now: Date, format: InAppEventDateText = .current
    ) -> [String] {
        pastDateIDs(failure, plan: plan).compactMap { id in
            // Any schedule's: the one with the date that has passed.
            guard let event = events.first(where: { $0.id == id }), event.state.isBeforeApproval,
                  let rule = event.brokenDateRules(now: now)?.first(where: { $0 == .publishStartPassed || $0 == .eventStartPassed }),
                  let dates = event.dates(breaking: rule, now: now)
            else { return nil }
            let text = rule.text(dates, format)
            let what = text.prefix(1).lowercased() + String(text.dropFirst())
            let field = rule.field.title
            return String(localized: "“\(displayName(of: event))”: \(what) Change “\(field)” on the event’s page (Fix…), then Submit again.")
        }
    }

    /// The events a refusal over a date that has passed is about: the
    /// event the step added, else the ones its reasons name, else the
    /// plan's. Empty when it isn't about one.
    private static func pastDateIDs(_ failure: SubmissionFailure, plan: SubmissionPlan) -> [String] {
        guard failure.message.localizedCaseInsensitiveContains(pastDateReason) else { return [] }
        switch failure.step {
        case let .addEvent(id): return [id]
        case .send:
            let named = plan.eventIDs.filter { failure.message.contains("(\(AppStoreConnectError.eventMarker)\($0))") }
            return named.isEmpty ? plan.eventIDs : named
        case .attachBuild, .encryption, .release, .phasedRelease, .createSubmission, .addVersion, .removeEvent: return []
        }
    }

    /// The events of a refusal that's only about dates that had passed
    /// (each reason App Store Connect gave is `pastDateReason`), for
    /// `SubmitFailureNote`; nil for any other refusal.
    static func onlyPastDateEventIDs(_ failure: SubmissionFailure, plan: SubmissionPlan) -> [String]? {
        let ids = pastDateIDs(failure, plan: plan)
        guard !ids.isEmpty else { return nil }
        // "This resource cannot be reviewed.\n• Supplied date must be in the future (In-App Event 1)\n• …"
        let reasons = failure.message.components(separatedBy: "•").dropFirst()
        guard reasons.allSatisfy({ $0.localizedCaseInsensitiveContains(pastDateReason) }) else { return nil }
        return ids
    }

    /// App Store Connect's words for a date that has passed.
    static let pastDateReason = "Supplied date must be in the future"

    /// "(In-App Event 6740000000)" in App Store Connect's reasons, as the
    /// event's name: "(“Holidays 2026”)".
    static func namingEvents(in message: String, events: [InAppEvent]) -> String {
        var text = message
        for event in events {
            text = text.replacingOccurrences(of: "(\(AppStoreConnectError.eventMarker)\(event.id))", with: "(“\(displayName(of: event))”)")
        }
        return text
    }
}
