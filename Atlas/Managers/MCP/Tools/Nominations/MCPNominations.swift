//
//  MCPNominations.swift
//  Atlas
//

import Foundation

/// What the Nominations tools share: the app's nominations as the section
/// shows them (App Store Connect's, this Mac's drafts and edits on top),
/// one as JSON, and the parsing of a date.
@MainActor
enum MCPNominations {
    /// The section's model for `app`, read: App Store Connect's
    /// nominations and what Atlas suggests from.
    static func load(_ app: StoreApp, store: NominationsStore, in context: MCPToolContext, now: Date) async -> NominationsViewModel {
        let model = NominationsViewModel(app: app, services: context.workspace.services.nominations, store: store, queue: context.workspace.changes)
        model.now = { now }
        await model.load()
        return model
    }

    /// Why App Store Connect couldn't be read, for the result; nil when it
    /// was.
    static func readProblem(_ model: NominationsViewModel) -> String? {
        switch model.problem {
        case .keyRole: String(localized: "This key can’t read or create nominations: the person needs an Admin or App Manager key.", comment: "kind:error")
        case .offline: String(localized: "The Mac is offline: only drafts on this Mac are listed.", comment: "kind:error")
        case let .failed(copy): copy.text
        case nil: nil
        }
    }

    static func json(_ nomination: Nomination, in model: NominationsViewModel) -> JSONValue {
        let content = nomination.content
        var object: [String: JSONValue] = [
            "id": .string(nomination.id),
            "state": .string(nomination.state.rawValue),
            "where": .string(nomination.isInAppStoreConnect ? "appStoreConnect" : "thisMac"),
            "name": .string(content.trimmedName),
            "description": .string(content.trimmedDescription),
            "deviceFamilies": .array(content.devices.map { .string($0.rawValue) }),
            "locales": .array(content.locales.map(JSONValue.string)),
            "territories": content.isEverywhere ? "ALL" : .array(content.territories.map(JSONValue.string)),
            "launchInSelectMarketsFirst": .bool(content.launchInSelectMarketsFirst),
            "preOrderEnabled": .bool(content.preOrderEnabled),
            "inAppEvents": .array(content.eventIDs.map { ["id": .string($0), "name": .string(model.eventName($0, in: nomination))] }),
            "supplementalMaterialsUris": .array(content.materials.map(JSONValue.string)),
            "apps": .array(([model.app.id] + content.appIDs.filter { $0 != model.app.id }).map {
                ["id": .string($0), "name": .string(model.appName($0, in: nomination))]
            }),
            "queuedInReviewAndPush": .array(model.queued(nomination.id).keys.map(\.rawValue).sorted().map(JSONValue.string)),
            "needs": .string(model.need(nomination).text),
        ]
        object.merge(optionals(nomination, in: model)) { $1 }
        return .object(object)
    }

    /// What only some nominations have: a type, dates, notes, who made it,
    /// what's missing, Apple's refusal.
    private static func optionals(_ nomination: Nomination, in model: NominationsViewModel) -> [String: JSONValue] {
        let content = nomination.content
        let missing = nomination.isEditable ? content.missing : []
        let texts: [String: String?] = [
            "type": content.type?.rawValue,
            "publishStartDate": content.publishStart.map(AppStoreConnectDate.text),
            "publishEndDate": content.publishEnd.map(AppStoreConnectDate.text),
            "notes": content.trimmedNotes.isEmpty ? nil : content.trimmedNotes,
            "createdDate": nomination.createdDate.map(AppStoreConnectDate.text),
            "submittedDate": nomination.submittedDate.map(AppStoreConnectDate.text),
            "createdBy": nomination.createdBy,
            "submittedBy": nomination.submittedBy,
            "suggestedBy": nomination.suggestedBy,
            "appleRefused": model.refusal(for: nomination.id)?.details,
        ]
        var object = texts.compactMapValues { $0.map(JSONValue.string) }
        if model.isEdited(nomination) { object["changedOnThisMac"] = .bool(true) }
        if !missing.isEmpty { object["missing"] = .array(missing.map(JSONValue.string)) }
        return object
    }

    /// A day (2027-02-02) or an ISO 8601 date and time; a day alone is
    /// that day in this Mac's time zone.
    static func date(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if let date = AppStoreConnectDate.date(text) { return date }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 9))
    }

    static let dateExpected = String(localized: "a day, e.g. 2027-02-02, or an ISO 8601 date and time", comment: "kind:error")
}
