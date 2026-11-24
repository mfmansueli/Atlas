//
//  ProposeEventDetailsTool.swift
//  Atlas
//

import Foundation

/// `propose_event_details`: an existing draft event's deep link, purpose,
/// priority or primary language, each queued as a change that waits for
/// the person to accept it on the event's page or in Review & Push, then
/// pushed as `PATCH /v1/appEvents/{id}` with that attribute alone; and its
/// dates (publishStart, eventStart, eventEnd), one change with
/// `territorySchedules`, each schedule keeping its territories. A value
/// App Store Connect would refuse is refused with the fix, and so are
/// dates that break Apple's rules at the tool's clock, or an event whose
/// territories Atlas doesn't know. Dates for an event whose dates the
/// person already queued never overwrite theirs: they wait beside them as
/// a suggestion, accepted or dismissed on the event's page or in Review &
/// Push.
struct ProposeEventDetailsTool: MCPTool {
    var store = InAppEventsStore.shared
    /// The clock the dates are checked against; tests pin it.
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_event_details",
        title: "Propose an In-App Event's details",
        description: """
        Proposes details of an existing In-App Event that's still editable (draft, ready for review or rejected; see \
        get_in_app_events' `editable`): deepLink (where Open on the card goes: a universal link https://… on a domain in \
        the app's Associated Domains, or the app's own scheme myapp://…; App Store Connect won't take the event to App \
        Review without one), purpose (APPROPRIATE_FOR_ALL_USERS, ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or \
        BRING_BACK_LAPSED_USERS), priority (HIGH or NORMAL), primaryLocale (a language the event is written in, e.g. \
        en-US), and its dates: publishStart (from when the card shows), eventStart and eventEnd, ISO 8601 with a time \
        zone (2026-11-21T18:00:00Z or 2026-11-21T15:00:00-03:00). Send only the ones to change; a date left out stays as \
        it will be (queued, else App Store Connect's). Dates are checked at the time you send them: all in the future \
        (App Store Connect refuses a date that has passed: "Supplied date must be in the future"), the event lasting 15 \
        minutes to 31 days, the card showing at most 14 days before the start and no later than it; get_in_app_events' \
        missingForReview says which date is wrong and `suggested` gives a publishStart that works. The dates go as one \
        change keeping the event's countries and regions, refused when Atlas doesn't know them (datesEditable false). \
        When the person already queued dates of their own (get_in_app_events' queuedDates with `by` not you), yours \
        never replace them: omitted dates come from theirs, and yours wait beside them as a suggestion (status \
        "suggested", with personsDates) that the person accepts or dismisses; sending dates again replaces it. \
        Each change is queued in Review & Push, waiting for the person to accept it; a value App Store Connect would \
        refuse is refused with how to fix it (status "refused"). `warning` says when App Review (up to 2 days; the event \
        shows only once it's approved) may not approve it before its card shows or it starts; it doesn't block. Before \
        proposing a deep link, check in the project that the app opens it on this event, and report what you found with \
        report_deep_link_check. Nothing reaches App Store Connect until the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "deepLink": MCPToolDefinition.string("Where Open goes: https://alba.app/events/new-year or alba://events/new-year."),
                "purpose": MCPToolDefinition.string("APPROPRIATE_FOR_ALL_USERS, ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or BRING_BACK_LAPSED_USERS."),
                "priority": MCPToolDefinition.string("HIGH or NORMAL."),
                "primaryLocale": MCPToolDefinition.string("A language the event is written in, e.g. en-US."),
                "publishStart": MCPToolDefinition.string(
                    "From when the card shows, ISO 8601 with a time zone: in the future, at most 14 days before eventStart."
                ),
                "eventStart": MCPToolDefinition.string("When the event starts, ISO 8601 with a time zone, e.g. 2026-11-23T00:00:00Z: in the future."),
                "eventEnd": MCPToolDefinition.string("When it ends, ISO 8601 with a time zone: 15 minutes to 31 days after eventStart."),
                "reason": MCPToolDefinition.string("Why, in one sentence, for the person."),
                "evidence": ["type": "array", "items": ["type": "string"], "description": "Where it comes from: files and lines."],
            ],
            required: ["appId", "eventId", "reason"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        let event = try await RenderEventArtworkTool.event(eventID, of: app, in: context)
        let target = "\(app.name) · \(event.referenceName) · details"
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        let reason = try arguments.string("reason")
        var values: [InAppEventDetail: String] = [:]
        for detail in InAppEventDetail.allCases {
            if let value = try arguments.optionalString(detail.rawValue) { values[detail] = value }
        }
        let builder = InAppEventChangeBuilder(appID: app.id)
        let changes = context.workspace.changes.changes(for: app.id, section: .inAppEvents)
        let sentDates = try Self.dates(in: arguments)
        let now = now()
        var reasons = Self.problems(
            values, of: event, appName: app.name, drafted: Set(builder.drafts(for: event.id, in: changes).keys), sendsDates: !sentDates.isEmpty
        )
        var dates = builder.dates(of: event, in: changes)
        if !sentDates.isEmpty, event.state.isEditable {
            reasons += Self.dateProblems(sentDates, into: &dates, of: event, now: now)
        }
        guard reasons.isEmpty else { return Self.refused(reasons, target: target) }

        let written = queue(values, dates: sentDates.isEmpty ? nil : dates, of: event, app: app, reason: reason, in: context)
        // A check of another deep link says nothing about this one.
        if let deepLink = values[.deepLink], !written.queued.isEmpty {
            store.dropDeepLinkReport(for: app.id, eventID: event.id, unlessFor: deepLink)
        }
        var result = Self.result(written, of: event, builder: builder)
        let warnings = dates.map { InAppEventReviewWarning.warnings(for: $0, now: now) } ?? []
        if !warnings.isEmpty {
            result["warning"] = .string(warnings.map(\.text).joined(separator: " "))
            result["reviewWarnings"] = .array(warnings.map(GetInAppEventsTool.warningJSON))
        }
        if values[.deepLink] != nil, store.deepLinkReport(for: app.id, eventID: event.id, deepLink: values[.deepLink]) == nil {
            result["next"] = .string(String(localized: """
            Check in the project that the app opens this deep link on this event (cold launch and already open, after \
            onboarding, before the event starts, without a paywall when it costs nothing) and report it with \
            report_deep_link_check.
            """))
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [
            .init(target: target, outcome: written.queued.isEmpty && written.suggested == nil ? .read : .proposed),
        ])
    }

    /// What was queued, what App Store Connect already has, and dates
    /// kept beside the person's own.
    struct Written {
        var queued: [JSONValue] = []
        var unchanged: [String] = []
        /// The dates, when the person queued dates of their own: they wait
        /// beside the person's change, which stays.
        var suggested: JSONValue?
        /// The person's queued dates, kept.
        var personsDates: PendingChange?
        /// The dates sent are the ones the person queued.
        var sameAsPersons = false
    }

    /// Queues a change per detail, and one for `dates` when sent, checked
    /// at the tool's clock.
    private func queue(
        _ values: [InAppEventDetail: String], dates: InAppEventDates?, of event: InAppEvent, app: StoreApp, reason: String, in context: MCPToolContext
    ) -> Written {
        let builder = InAppEventChangeBuilder(appID: app.id)
        var written = Written()
        for detail in InAppEventDetail.allCases {
            guard let value = values[detail] else { continue }
            let normalized = detail == .primaryLocale ? StoreLocaleCatalog.locale(code: value)?.code ?? value : value
            guard let change = builder.detailChange(detail, to: normalized, of: event, appName: app.name, source: context.source, reason: reason)
            else {
                written.unchanged.append(detail.rawValue)
                continue
            }
            context.workspace.changes.upsert(change)
            written.queued.append(["detail": .string(detail.rawValue), "value": .string(normalized), "changeId": .string(change.id)])
        }
        guard let dates else { return written }
        let queue = context.workspace.changes
        if let persons = builder.queuedDates(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents)), !persons.source.isAssistant {
            suggest(dates, beside: persons, of: event, reason: reason, in: context, into: &written)
            return written
        }
        if let change = builder.datesChange(to: dates, of: event, now: now(), source: context.source, reason: reason) {
            context.workspace.changes.upsert(change)
            var json = GetInAppEventsTool.datesJSON(dates)
            json["detail"] = .string(InAppEventChangeBuilder.schedulesAttribute)
            json["changeId"] = .string(change.id)
            written.queued.append(.object(json))
        } else {
            written.unchanged.append(InAppEventChangeBuilder.schedulesAttribute)
        }
        return written
    }

    /// The person queued dates of their own: `dates` wait beside them as
    /// the change's alternative (replacing this assistant's older one),
    /// never over them. The same dates as theirs change nothing.
    private func suggest(
        _ dates: InAppEventDates, beside persons: PendingChange, of event: InAppEvent, reason: String, in context: MCPToolContext,
        into written: inout Written
    ) {
        let builder = InAppEventChangeBuilder(appID: persons.appID)
        let queue = context.workspace.changes
        written.personsDates = persons
        guard InAppEventChangeBuilder.datesValue(in: persons) != dates else {
            // Nothing to choose between: what the person queued stays alone.
            if persons.alternative?.source == context.source { queue.setAlternative(nil, id: persons.id) }
            written.sameAsPersons = true
            written.unchanged.append(InAppEventChangeBuilder.schedulesAttribute)
            return
        }
        guard let alternative = builder.datesAlternative(to: dates, of: event, now: now(), source: context.source, reason: reason) else {
            written.unchanged.append(InAppEventChangeBuilder.schedulesAttribute)
            return
        }
        queue.setAlternative(alternative, id: persons.id)
        var json = GetInAppEventsTool.datesJSON(dates)
        json["detail"] = .string(InAppEventChangeBuilder.schedulesAttribute)
        json["changeId"] = .string(persons.id)
        written.suggested = .object(json)
    }

    private static func result(_ written: Written, of event: InAppEvent, builder: InAppEventChangeBuilder) -> [String: JSONValue] {
        let status: JSONValue = !written.queued.isEmpty ? "queued" : written.suggested != nil ? "suggested" : "unchanged"
        var result: [String: JSONValue] = [
            "status": status,
            "queued": .array(written.queued),
            "showsIn": .string("The event’s page in In-App Events and Review & Push → \(builder.group(event)), waiting for the person to accept it"),
        ]
        if !written.unchanged.isEmpty {
            result["unchanged"] = .array(written.unchanged.map(JSONValue.string))
            result["unchangedNote"] = written.sameAsPersons
                ? "The person already queued these dates; nothing else was queued for them."
                : "App Store Connect already has these values; nothing was queued for them."
        }
        if let persons = written.personsDates, let theirs = InAppEventChangeBuilder.datesValue(in: persons) {
            var json = GetInAppEventsTool.datesJSON(theirs)
            json["changeId"] = .string(persons.id)
            json["by"] = .string(persons.source.title)
            result["personsDates"] = .object(json)
        }
        if let suggested = written.suggested {
            result["suggested"] = .array([suggested])
            result["note"] = .string(String(localized: """
            The person already queued dates of their own (personsDates): those are kept. Yours wait beside them as a \
            suggestion, on the event’s page under Details and in Review & Push, where the person accepts yours (they replace \
            theirs) or dismisses them (theirs stay). Sending dates again replaces your suggestion.
            """))
        }
        return result
    }

    /// Why App Store Connect would refuse the values, or the event can't
    /// take them.
    static func problems(
        _ values: [InAppEventDetail: String], of event: InAppEvent, appName: String, drafted: Set<String>, sendsDates: Bool = false
    ) -> [String] {
        guard !values.isEmpty || sendsDates else {
            return [String(localized: "Send at least one of deepLink, purpose, priority, primaryLocale, publishStart, eventStart or eventEnd.")]
        }
        guard event.state.isEditable else {
            return [String(localized: "“\(event.referenceName)” is \(event.state.rawValue): only a draft, an event ready for review or a rejected one can change.")]
        }
        var problems: [String] = []
        for detail in InAppEventDetail.allCases {
            guard let value = values[detail] else { continue }
            if let problem = detail.problem(value, appName: appName) {
                problems.append("\(detail.rawValue): \(problem)")
            } else if detail == .primaryLocale, let code = StoreLocaleCatalog.locale(code: value)?.code,
                      event.localization(code) == nil, !drafted.contains(code)
            {
                let written = event.localizations.map(\.locale).formatted(.list(type: .and))
                problems.append(String(localized: """
                primaryLocale: “\(event.referenceName)” isn’t written in \(code) (it has \(written)). Write it with \
                propose_event_texts first, or choose one of those.
                """))
            }
        }
        return problems
    }

    /// The dates sent, by field. One that isn't an ISO 8601 date and time
    /// with a time zone throws.
    static func dates(in arguments: MCPToolArguments) throws -> [InAppEventDateField: Date] {
        var dates: [InAppEventDateField: Date] = [:]
        for field in InAppEventDateField.allCases {
            guard let text = try arguments.optionalString(field.rawValue) else { continue }
            guard let date = AppStoreConnectDate.date(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw MCPToolError.invalidArgument(name: field.rawValue, expected: String(localized: """
                an ISO 8601 date and time with its time zone, e.g. 2026-11-21T18:00:00Z or 2026-11-21T15:00:00-03:00 (a date alone \
                doesn’t say when on that day)
                """))
            }
            dates[field] = date
        }
        return dates
    }

    /// Why the `sent` dates can't be queued, with the others as they will
    /// be (written into `dates`): Atlas can't change them, or they break a
    /// rule at `now`.
    static func dateProblems(
        _ sent: [InAppEventDateField: Date], into dates: inout InAppEventDates?, of event: InAppEvent, now: Date,
        format: InAppEventDateText = .current
    ) -> [String] {
        if let problem = InAppEventChangeBuilder.datesEditProblem(of: event) { return ["dates: \(problem)"] }
        guard var merged = dates else { return [] }
        for (field, date) in sent {
            merged[field] = date
        }
        dates = merged
        return merged.broken(now: now).map { rule in
            let suggestion = rule.field == .publishStart ? merged.suggestedPublishStart(now: now, calendar: format.calendar) : nil
            let iso = suggestion.map { " (publishStart \(AppStoreConnectDate.text($0)))" } ?? ""
            return "\(rule.field.rawValue): \(rule.text(merged, format)) \(rule.fix(suggestion: suggestion, format))\(iso)"
        }
    }

    private static func refused(_ reasons: [String], target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "reasons": .array(reasons.map(JSONValue.string))]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }
}
