//
//  InAppEventChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns an event's edited texts into Review & Push changes, and reads
/// queued changes back, so the queue is where edits live.
///
/// - A text of a language the event has is one change: `PATCH` its
///   localization, restorable, with a conflict check on the text.
/// - A language the event doesn't have yet is one change for its texts: a
///   single `POST` creates the localization with them.
/// - Ids are `inAppEvents.<appID>.<eventID>.<locale>.<field>`, or
///   `….<locale>.new` for a new language.
struct InAppEventChangeBuilder: Hashable, Sendable {
    let appID: StoreApp.ID

    static let newSuffix = "new"

    var idPrefix: String { "inAppEvents.\(appID)." }

    func owns(_ change: PendingChange) -> Bool {
        change.section == .inAppEvents && change.appID == appID && change.id.hasPrefix(idPrefix)
    }

    func changeID(eventID: String, locale: String, field: InAppEventField) -> String {
        "\(idPrefix)\(eventID).\(locale).\(field.rawValue)"
    }

    func newChangeID(eventID: String, locale: String) -> String {
        "\(idPrefix)\(eventID).\(locale).\(Self.newSuffix)"
    }

    /// "In-App Events · Winter Reflection 2026".
    func group(_ event: InAppEvent) -> String {
        String(localized: "In-App Events · \(event.referenceName)")
    }

    /// The change for one text of a language the event has; nil when the
    /// text is what App Store Connect has.
    func fieldChange(
        _ field: InAppEventField, to value: String, in localization: InAppEventLocalization, of event: InAppEvent, source: ChangeSource
    ) -> PendingChange? {
        let old = localization.text(field)
        guard value != old else { return nil }
        let path = "/v1/\(InAppEventWriteDocument.type)/\(localization.id)"
        guard let request = try? PushRequest.json(.patch, path, InAppEventWriteDocument.update(id: localization.id, field: field, value: value)),
              let restore = try? PushRequest.json(.patch, path, InAppEventWriteDocument.update(id: localization.id, field: field, value: old))
        else { return nil }
        return PendingChange(
            id: changeID(eventID: event.id, locale: localization.locale, field: field),
            appID: appID, section: .inAppEvents, group: group(event), groupID: event.id,
            title: "\(Self.localeName(localization.locale)) · \(field.title)", flagRegion: Self.region(localization.locale),
            oldValue: old, newValue: value, source: source, blockedReason: Self.problem(field, value),
            requests: [request], restoreRequests: [restore],
            conflictCheck: ConflictCheck(
                path: "\(path)?fields[\(InAppEventWriteDocument.type)]=\(field.rawValue)", keyPath: ["data", "attributes", field.rawValue],
                expected: old.isEmpty ? nil : old
            )
        )
    }

    /// The change that creates a language with its texts; nil when every
    /// text is empty.
    func newLanguageChange(_ texts: [InAppEventField: String], locale: String, of event: InAppEvent, source: ChangeSource) -> PendingChange? {
        let written = texts.filter { !$0.value.isEmpty }
        guard !written.isEmpty,
              let request = try? PushRequest.json(
                  .post, "/v1/\(InAppEventWriteDocument.type)", InAppEventWriteDocument.create(eventID: event.id, locale: locale, texts: written)
              )
        else { return nil }
        let fields = InAppEventField.allCases.filter { written[$0] != nil }
        let problem = fields.lazy.compactMap { Self.problem($0, written[$0] ?? "") }.first
        return PendingChange(
            id: newChangeID(eventID: event.id, locale: locale),
            appID: appID, section: .inAppEvents, group: group(event), groupID: event.id,
            title: "\(Self.localeName(locale)) · \(fields.map(\.title).formatted(.list(type: .and)))", flagRegion: Self.region(locale),
            oldValue: "", newValue: fields.compactMap { written[$0] }.joined(separator: "\n"), source: source, blockedReason: problem,
            requests: [request]
        )
    }

    /// The texts queued for an event, by locale and field.
    func drafts(for eventID: String, in changes: [PendingChange]) -> [String: [InAppEventField: String]] {
        var drafts: [String: [InAppEventField: String]] = [:]
        let prefix = "\(idPrefix)\(eventID)."
        for change in changes where owns(change) && change.id.hasPrefix(prefix) {
            let rest = change.id.dropFirst(prefix.count)
            guard let dot = rest.lastIndex(of: ".") else { continue }
            let locale = String(rest[..<dot])
            let last = String(rest[rest.index(after: dot)...])
            if last == Self.newSuffix {
                let texts = InAppEventWriteDocument.decode(change.requests.first?.body)?.texts ?? [:]
                drafts[locale, default: [:]].merge(texts) { _, new in new }
            } else if let field = InAppEventField(rawValue: last) {
                drafts[locale, default: [:]][field] = change.newValue
            }
        }
        return drafts
    }

    /// Who queued a language's texts, for the provenance of an undo.
    func changeIDs(eventID: String, locale: String) -> [String] {
        InAppEventField.allCases.map { changeID(eventID: eventID, locale: locale, field: $0) } + [newChangeID(eventID: eventID, locale: locale)]
    }

    /// "Event Name is 34 characters; the limit is 30."
    static func problem(_ field: InAppEventField, _ value: String) -> String? {
        value.count > field.limit ? String(localized: "\(field.title) is \(value.count) characters; the limit is \(field.limit).") : nil
    }

    static func localeName(_ code: String) -> String {
        StoreLocaleCatalog.locale(code: code)?.name ?? code
    }

    static func region(_ code: String) -> String? {
        StoreLocaleCatalog.locale(code: code)?.regionCode
    }
}
