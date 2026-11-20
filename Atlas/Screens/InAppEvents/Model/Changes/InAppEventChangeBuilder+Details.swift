//
//  InAppEventChangeBuilder+Details.swift
//  Atlas
//

import Foundation

// An event's deep link, purpose, priority and primary language as Review
// & Push changes: one per attribute, `inAppEvents.<appID>.<eventID>.details.<attribute>`,
// each a plain `PATCH /v1/appEvents/{id}` with only that attribute, so
// `PushSchedule` sends it beside the others (two of the same event wait
// for each other: they write the same path). Restorable, with a conflict
// check on the attribute. An assistant's waits for the person to accept it.
extension InAppEventChangeBuilder {
    static let detailsSegment = "details"
    static let eventType = "appEvents"

    func detailChangeID(eventID: String, detail: InAppEventDetail) -> String {
        "\(idPrefix)\(eventID).\(Self.detailsSegment).\(detail.rawValue)"
    }

    /// The change that sets `detail` to `value` (nil or empty clears it);
    /// nil when it's what App Store Connect has, or the request can't be
    /// written.
    func detailChange(
        _ detail: InAppEventDetail, to value: String?, of event: InAppEvent, appName: String = "", source: ChangeSource,
        reason: String = ""
    ) -> PendingChange? {
        let new = Self.normalized(value, detail)
        let old = detail.value(in: event)
        guard new != old else { return nil }
        let path = "/v1/\(Self.eventType)/\(event.id)"
        guard let request = Self.detailRequest(eventID: event.id, detail: detail, value: new),
              let restore = Self.detailRequest(eventID: event.id, detail: detail, value: old)
        else { return nil }
        var change = PendingChange(
            id: detailChangeID(eventID: event.id, detail: detail),
            appID: appID, section: .inAppEvents, group: group(event), groupID: event.id,
            title: detail.title,
            oldValue: old.map { detail.display($0, appName: appName) } ?? "",
            newValue: new.map { detail.display($0, appName: appName) } ?? "",
            source: source,
            blockedReason: new == nil && detail != .deepLink ? detail.problem(nil) : detail.problem(new, appName: appName),
            requests: [request], restoreRequests: [restore],
            conflictCheck: ConflictCheck(
                path: "\(path)?fields[\(Self.eventType)]=\(detail.rawValue)", keyPath: ["data", "attributes", detail.rawValue], expected: old
            )
        )
        let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { change.groupNote = note }
        if source.isAssistant {
            change.awaitingAcceptance = String(localized: "Look at it, then accept it here or on the event’s page.")
        }
        return change
    }

    /// The `PATCH` that writes one attribute: `null` clears it.
    static func detailRequest(eventID: String, detail: InAppEventDetail, value: String?) -> PushRequest? {
        let document: [String: Any] = ["data": [
            "type": eventType, "id": eventID, "attributes": [detail.rawValue: value.map { $0 as Any } ?? NSNull()],
        ]]
        guard let body = try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .withoutEscapingSlashes]) else { return nil }
        return PushRequest(method: .patch, path: "/v1/\(eventType)/\(eventID)", body: body)
    }

    /// The value a detail change writes; nil when it clears it, or when the
    /// change isn't one.
    static func detailValue(in change: PendingChange) -> (detail: InAppEventDetail, value: String?)? {
        guard let request = change.requests.first, request.method == .patch, request.path.hasPrefix("/v1/\(eventType)/"),
              let object = request.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let attributes = (object["data"] as? [String: Any])?["attributes"] as? [String: Any],
              attributes.count == 1, let (key, value) = attributes.first, let detail = InAppEventDetail(rawValue: key)
        else { return nil }
        return (detail, value as? String)
    }

    /// The detail changes waiting for `eventID`, by detail.
    func queuedDetails(for eventID: String, in changes: [PendingChange]) -> [InAppEventDetail: PendingChange] {
        var found: [InAppEventDetail: PendingChange] = [:]
        for detail in InAppEventDetail.allCases {
            let id = detailChangeID(eventID: eventID, detail: detail)
            if let change = changes.first(where: { $0.id == id && owns($0) }) { found[detail] = change }
        }
        return found
    }

    /// The detail as it will be once pushed: what's queued, else App Store
    /// Connect's.
    func value(_ detail: InAppEventDetail, of event: InAppEvent, in changes: [PendingChange]) -> String? {
        if let change = queuedDetails(for: event.id, in: changes)[detail], let queued = Self.detailValue(in: change) { return queued.value }
        return detail.value(in: event)
    }

    /// Trimmed, nil when empty; a primary language as its catalog code.
    private static func normalized(_ value: String?, _ detail: InAppEventDetail) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if detail == .primaryLocale { return StoreLocaleCatalog.locale(code: trimmed)?.code ?? trimmed }
        return trimmed
    }
}
