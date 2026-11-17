//
//  InAppEventChangeBuilder+NewEvent.swift
//  Atlas
//

import Foundation

// A new event: one change that creates the draft (`POST /v1/appEvents`)
// and then each language it's created with, which refer to the new event
// by `{createdID}`. Review & Push shows it as "Create “Winter Reflection
// 2026”" with what it's created with under it. For every country or
// region, its schedule's territories are `{everyTerritory}`, which the push
// fills in from App Store Connect (`NewInAppEventEverywhere`).
extension InAppEventChangeBuilder {
    static let newEventMarker = "new-event"

    /// `inAppEvents.<appID>.new-event.<token>`.
    func newEventChangeID(token: String) -> String {
        "\(idPrefix)\(Self.newEventMarker).\(token)"
    }

    func isNewEvent(_ change: PendingChange) -> Bool {
        owns(change) && change.id.hasPrefix("\(idPrefix)\(Self.newEventMarker).")
    }

    /// The change that creates `event`, with what an assistant said about
    /// it: why (`reason`) and where it found it (`evidence`).
    func newEventChange(
        _ event: NewInAppEvent,
        token: String = UUID().uuidString.lowercased(),
        source: ChangeSource = .you,
        reason: String = "",
        evidence: [String] = []
    ) -> PendingChange? {
        let document = Self.createDocument(event, appID: appID)
        guard let body = try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .withoutEscapingSlashes]) else { return nil }
        var requests = [PushRequest(method: .post, path: Self.newEventPath, body: body)]
        for locale in event.texts.keys.sorted() {
            guard let texts = event.texts[locale], texts.values.contains(where: { !$0.isEmpty }),
                  let request = try? PushRequest.json(
                      .post, "/v1/\(InAppEventWriteDocument.type)",
                      InAppEventWriteDocument.create(eventID: PushRequest.createdIDPlaceholder, locale: locale, texts: texts)
                  )
            else { continue }
            requests.append(request)
        }
        let id = newEventChangeID(token: token)
        let title = String(localized: "Create “\(event.trimmedReferenceName)”")
        var change = PendingChange(
            id: id,
            appID: appID, section: .inAppEvents, group: String(localized: "In-App Events · New"),
            title: title,
            oldValue: "",
            newValue: "\(event.badge.title) · \(Self.datesText(event))",
            source: source, blockedReason: event.problem, requests: requests
        )
        change.creation = PendingCreation(
            id: id,
            title: title,
            detail: String(localized: """
            A new In-App Event, created as a draft. Add its event card and details page images in App Store Connect, then \
            submit it for review.
            """),
            source: source,
            fields: Self.fields(of: event, source: source, reason: reason, evidence: evidence)
        )
        return change
    }

    static let newEventPath = "/v1/appEvents"

    /// The `POST /v1/appEvents` document.
    static func createDocument(_ event: NewInAppEvent, appID: StoreApp.ID) -> [String: Any] {
        var attributes: [String: Any] = [
            "referenceName": event.trimmedReferenceName,
            "badge": event.badge.rawValue,
            "primaryLocale": event.primaryLocale,
            "priority": event.priority.rawValue,
            "purpose": event.purpose.rawValue,
            "purchaseRequirement": event.purchaseRequirement.rawValue,
            "territorySchedules": [[
                "territories": event.territories.isEmpty ? [NewInAppEventEverywhere.placeholder] : event.territories,
                "publishStart": AppStoreConnectDate.text(event.publishStart),
                "eventStart": AppStoreConnectDate.text(event.eventStart),
                "eventEnd": AppStoreConnectDate.text(event.eventEnd),
            ]],
        ]
        if !event.trimmedDeepLink.isEmpty { attributes["deepLink"] = event.trimmedDeepLink }
        return ["data": [
            "type": "appEvents",
            "attributes": attributes,
            "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
        ]]
    }

    /// "Dec 1 – Dec 31".
    private static func datesText(_ event: NewInAppEvent) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(event.eventStart.formatted(style)) – \(event.eventEnd.formatted(style))"
    }

    private static func fields(of event: NewInAppEvent, source: ChangeSource, reason: String, evidence: [String]) -> [PendingChangePart] {
        let when = Date.FormatStyle(date: .abbreviated, time: .shortened)
        var fields: [(String, String, String)] = [
            ("event.badge", String(localized: "Badge"), event.badge.title),
            ("event.dates", String(localized: "Event dates"), "\(event.eventStart.formatted(when)) – \(event.eventEnd.formatted(when))"),
            ("event.publishStart", String(localized: "On the App Store from"), event.publishStart.formatted(when)),
            ("event.territories", String(localized: "Countries and regions"), event.territories.isEmpty
                ? String(localized: "All")
                : event.territories.joined(separator: ", ")),
            ("event.purpose", String(localized: "Purpose"), event.purpose.summary),
            ("event.priority", String(localized: "Priority"), event.priority.title),
            ("event.purchaseRequirement", String(localized: "Purchase"), event.purchaseRequirement.title),
        ]
        if !event.trimmedDeepLink.isEmpty { fields.append(("event.deepLink", String(localized: "Deep link"), event.trimmedDeepLink)) }
        for locale in event.texts.keys.sorted() {
            for field in InAppEventField.allCases {
                guard let value = event.texts[locale]?[field], !value.isEmpty else { continue }
                fields.append(("event.\(locale).\(field.rawValue)", "\(field.title) · \(localeName(locale))", value))
            }
        }
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reason.isEmpty { fields.append(("event.reason", String(localized: "Why"), reason)) }
        if !evidence.isEmpty { fields.append(("event.evidence", String(localized: "Found in"), evidence.joined(separator: "\n"))) }
        return fields.map { PendingChangePart(id: $0.0, title: $0.1, oldValue: "", newValue: $0.2, source: source) }
    }
}
