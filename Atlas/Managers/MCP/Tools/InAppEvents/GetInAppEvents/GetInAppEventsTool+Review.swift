//
//  GetInAppEventsTool+Review.swift
//  Atlas
//

import Foundation

// What an event still needs before App Review (`missingForReview`, with a
// date that has passed), what App Review's time may do to it
// (`reviewWarnings`), its details and dates waiting in Review & Push
// (`queuedDetails`, `queuedDates`, with an assistant's dates waiting beside
// the person's as its `suggestion`), whether Atlas can change its dates
// (`datesEditable`), whether the app's project claims its deep link
// (`deepLinkClaim`) and the last check of it in the code
// (`deepLinkCheck`).
extension GetInAppEventsTool {
    /// The deep link the event will have once pushed: queued, else App
    /// Store Connect's.
    static func deepLink(of event: InAppEvent, builder: InAppEventChangeBuilder, changes: [PendingChange]) -> String? {
        builder.value(.deepLink, of: event, in: changes)
    }

    static func reviewJSON(
        _ event: InAppEvent, appName: String, builder: InAppEventChangeBuilder, changes: [PendingChange], claims: ProjectLinkClaimsState,
        report: InAppEventDeepLinkReport?, now: Date = .now
    ) -> [String: JSONValue] {
        let queuedDetails = builder.queuedDetails(for: event.id, in: changes)
        let deepLink = deepLink(of: event, builder: builder, changes: changes)
        let claim = InAppEventLinkClaim.of(deepLink, in: claims)
        var object: [String: JSONValue] = [
            "deepLinkClaim": claimJSON(claim, claims: claims, appName: appName),
            "deepLinkCheck": report.map {
                reportJSON($0, dates: builder.dates(of: event, in: changes), suggested: builder.suggestedDates(for: event.id, in: changes)?.dates)
            } ?? .null,
        ]
        if !queuedDetails.isEmpty {
            object["queuedDetails"] = .object(Dictionary(uniqueKeysWithValues: queuedDetails.map { detail, change in
                let value = InAppEventChangeBuilder.detailValue(in: change)?.value
                return (detail.rawValue, JSONValue.object([
                    "value": value.map(JSONValue.string) ?? .null,
                    "changeId": .string(change.id),
                    "by": .string(change.source.title),
                    "waitingForAcceptance": .bool(change.awaitingAcceptance != nil),
                ]))
            }))
        }
        let queuedDates = builder.queuedDates(for: event.id, in: changes)
        if let queuedDates, let dates = InAppEventChangeBuilder.datesValue(in: queuedDates) {
            var json = datesJSON(dates)
            json["changeId"] = .string(queuedDates.id)
            json["by"] = .string(queuedDates.source.title)
            json["waitingForAcceptance"] = .bool(queuedDates.awaitingAcceptance != nil)
            if let blocked = queuedDates.blockedReason { json["blockedReason"] = .string(blocked) }
            if let (dates, alternative) = builder.suggestedDates(for: event.id, in: changes) {
                var suggestion = datesJSON(dates)
                suggestion["by"] = .string(alternative.source.title)
                if let note = alternative.note { suggestion["reason"] = .string(note) }
                suggestion["note"] = "Waits beside the person's dates for them to accept (it replaces theirs) or dismiss."
                json["suggestion"] = .object(suggestion)
            }
            object["queuedDates"] = .object(json)
        }
        guard event.state.isEditable else { return object }
        let editProblem = InAppEventChangeBuilder.datesEditProblem(of: event)
        object["datesEditable"] = .bool(editProblem == nil)
        if let editProblem { object["datesNotEditable"] = .string(editProblem) }
        let items = InAppEventReviewItem.items(for: event, changes: changes, builder: builder, claim: claim, appName: appName, now: now)
        object["missingForReview"] = .array(items.map { item in
            var json: [String: JSONValue] = ["item": .string(item.mcpValue), "state": .string(item.state.rawValue), "text": .string(item.text)]
            if let detail = item.detail { json["fix"] = .string(detail) }
            if !item.suggestedDates.isEmpty { json["suggested"] = suggestedJSON(item.suggestedDates) }
            return .object(json)
        })
        object["readyForReview"] = .bool(items.isEmpty)
        object["reviewWarnings"] = .array(InAppEventReviewWarning.warnings(for: event, queued: queuedDates, now: now).map(warningJSON))
        return object
    }

    /// A warning about App Review's time, as `reviewWarnings` and the
    /// propose tools' `warning` give it.
    static func warningJSON(_ warning: InAppEventReviewWarning) -> JSONValue {
        var json: [String: JSONValue] = ["item": .string(warning.mcpValue), "text": .string(warning.text)]
        if let detail = warning.detail { json["fix"] = .string(detail) }
        if !warning.suggestedDates.isEmpty { json["suggested"] = suggestedJSON(warning.suggestedDates) }
        return .object(json)
    }

    /// `{"publishStart": "2026-11-21T18:00:00Z"}`: what propose_event_details takes.
    static func suggestedJSON(_ dates: [InAppEventDateField: Date]) -> JSONValue {
        .object(Dictionary(uniqueKeysWithValues: dates.map { ($0.key.rawValue, JSONValue.string(AppStoreConnectDate.text($0.value))) }))
    }

    /// The three dates, ISO 8601 as App Store Connect takes them.
    static func datesJSON(_ dates: InAppEventDates) -> [String: JSONValue] {
        Dictionary(uniqueKeysWithValues: InAppEventDateField.allCases.map { ($0.rawValue, JSONValue.string(AppStoreConnectDate.text(dates[$0]))) })
    }

    private static func claimJSON(_ claim: InAppEventLinkClaim, claims: ProjectLinkClaimsState, appName: String) -> JSONValue {
        var json: [String: JSONValue] = ["state": .string(claim.mcpValue)]
        if let message = claim.message(appName: appName) { json["message"] = .string(message) }
        if let detail = claim.detail { json["fix"] = .string(detail) }
        if let read = claims.claims {
            json["schemes"] = .array(read.schemes.sorted().map(JSONValue.string))
            json["applinksDomains"] = .array(read.domains.sorted().map(JSONValue.string))
            if let build = read.build { json["projectBuild"] = .string(build) }
        }
        if let folder = claims.folder { json["projectFolder"] = .string(folder) }
        return .object(json)
    }

    /// A check of the deep link; `stale` with why when the event's start
    /// or end moved since (`dates` it will have), unless it was made for
    /// the `suggested` dates still waiting beside the person's.
    static func reportJSON(_ report: InAppEventDeepLinkReport, dates: InAppEventDates? = nil, suggested: InAppEventDates? = nil) -> JSONValue {
        let isStale = report.isStale(for: dates, suggested: suggested)
        var json: [String: JSONValue] = [
            "deepLink": .string(report.deepLink),
            "opens": .bool(report.opens),
            "shows": .string(report.shows),
            "beforeStart": .string(report.beforeStart),
            "needsPremium": .bool(report.needsPremium),
            "where": .string(report.location),
            "build": .string(report.build),
            "testedInSimulator": .bool(report.testedInSimulator),
            "problems": .array(report.problems.map(JSONValue.string)),
            "by": .string(report.client),
            "date": .string(report.date.formatted(.iso8601)),
            "stale": .bool(isStale),
        ]
        if let checked = report.checkedDates { json["checkedDates"] = .object(datesJSON(checked)) }
        if isStale, let checked = report.checkedDates, let dates {
            let text = { (date: Date) in AppStoreConnectDate.text(date) }
            json["staleReason"] = .string(String(localized: """
            Checked when the event was to run \(text(checked.eventStart)) – \(text(checked.eventEnd)); it now runs \
            \(text(dates.eventStart)) – \(text(dates.eventEnd)) (queued or App Store Connect's). What it shows before the \
            start (beforeStart) may name the old dates: check it again in the code and report it with report_deep_link_check.
            """))
        }
        return .object(json)
    }
}
