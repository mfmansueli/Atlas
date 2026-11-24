//
//  NominationChangeBuilder.swift
//  Atlas
//

import Foundation

/// The Review & Push rows of Nominations, each its own row: create a draft
/// in App Store Connect, update a draft, submit to Apple, archive, delete a
/// draft. A submit is only ever made after the person confirmed the Submit
/// sheet; an assistant's request to submit waits on the nomination instead.
/// The changes for one nomination share its group, "Nominations · <name>".
struct NominationChangeBuilder {
    let appID: StoreApp.ID

    enum Kind: String, CaseIterable, Sendable {
        case create
        case update
        case submit
        case archive
        case delete

        /// The row's title.
        var title: String {
            switch self {
            case .create: String(localized: "Create the draft", comment: "kind:other")
            case .update: String(localized: "Update the draft", comment: "kind:other")
            case .submit: String(localized: "Submit to Apple", comment: "kind:other")
            case .archive: String(localized: "Archive", comment: "kind:other")
            case .delete: String(localized: "Delete the draft", comment: "kind:other")
            }
        }
    }

    static let idPrefix = "nomination."
    static let path = "/v1/nominations"

    static func changeID(_ kind: Kind, nominationID: String) -> String {
        "\(idPrefix)\(kind.rawValue).\(nominationID)"
    }

    /// The kind and nomination of one of this section's changes; nil for
    /// any other change.
    static func parse(_ changeID: PendingChange.ID) -> (kind: Kind, nominationID: String)? {
        guard changeID.hasPrefix(idPrefix) else { return nil }
        let rest = changeID.dropFirst(idPrefix.count)
        guard let dot = rest.firstIndex(of: "."), let kind = Kind(rawValue: String(rest[..<dot])) else { return nil }
        return (kind, String(rest[rest.index(after: dot)...]))
    }

    /// The app's Nominations changes for one nomination, by kind.
    func queued(for nominationID: String, in changes: [PendingChange]) -> [Kind: PendingChange] {
        var found: [Kind: PendingChange] = [:]
        for change in changes where change.appID == appID {
            guard let parsed = Self.parse(change.id), parsed.nominationID == nominationID else { continue }
            found[parsed.kind] = change
        }
        return found
    }

    // MARK: - Changes

    /// "Create the draft": `POST /v1/nominations`, a draft Apple doesn't
    /// see until it's submitted.
    func create(_ nomination: Nomination, source: ChangeSource = .you, now: Date = .now) throws -> PendingChange {
        let content = nomination.content
        var change = try PendingChange(
            id: Self.changeID(.create, nominationID: nomination.id),
            appID: appID,
            section: .nominations,
            group: group(nomination),
            groupID: nomination.id,
            title: Kind.create.title,
            oldValue: String(localized: "Not in App Store Connect", comment: "kind:other"),
            newValue: Self.summary(content),
            source: source,
            requests: [PushRequest(method: .post, path: Self.path, body: NominationRequestBody.create(content))],
            createdAt: now
        )
        change.groupNote = String(localized: "Create a draft in App Store Connect. Apple doesn’t see it yet.", comment: "kind:description")
        return change
    }

    /// "Update the draft": `PATCH` with every field, against what App Store
    /// Connect has (`remote`).
    func update(_ nomination: Nomination, from remote: NominationContent, source: ChangeSource = .you, now: Date = .now) throws -> PendingChange {
        let fields = nomination.content.changedFields(from: remote)
        var change = try PendingChange(
            id: Self.changeID(.update, nominationID: nomination.id),
            appID: appID,
            section: .nominations,
            group: group(nomination),
            groupID: nomination.id,
            title: Kind.update.title,
            oldValue: String(localized: "Draft in App Store Connect", comment: "kind:other"),
            newValue: fields.map(\.title).joined(separator: ", "),
            source: source,
            requests: [PushRequest(method: .patch, path: "\(Self.path)/\(nomination.id)", body: NominationRequestBody.update(id: nomination.id, nomination.content))],
            createdAt: now
        )
        change.groupNote = String(localized: "Update the draft in App Store Connect.", comment: "kind:description")
        return change
    }

    /// "Submit to Apple": `PATCH submitted: true`. A draft on this Mac
    /// names itself by placeholder and waits for its create.
    func submit(_ nomination: Nomination, now: Date = .now) throws -> PendingChange {
        let id: String
        var dependsOn: PendingChange.ID?
        if nomination.isInAppStoreConnect {
            id = nomination.id
        } else {
            id = NominationPlaceholder(appID: appID, localID: nomination.id, name: nomination.content.trimmedName).token
            dependsOn = Self.changeID(.create, nominationID: nomination.id)
        }
        var change = try PendingChange(
            id: Self.changeID(.submit, nominationID: nomination.id),
            appID: appID,
            section: .nominations,
            group: group(nomination),
            groupID: nomination.id,
            title: Kind.submit.title,
            oldValue: String(localized: "Draft", comment: "kind:pill"),
            newValue: String(localized: "Submitted to Apple’s editors", comment: "kind:other"),
            requests: [PushRequest(method: .patch, path: "\(Self.path)/\(id)", body: NominationRequestBody.submit(id: id))],
            createdAt: now
        )
        change.dependsOn = dependsOn
        change.groupNote = String(localized: "Submit to Apple. After you push, you can only archive it.", comment: "kind:description")
        return change
    }

    /// "Archive": `PATCH archived: true` on a submitted nomination.
    func archive(_ nomination: Nomination, now: Date = .now) throws -> PendingChange {
        var change = try PendingChange(
            id: Self.changeID(.archive, nominationID: nomination.id),
            appID: appID,
            section: .nominations,
            group: group(nomination),
            groupID: nomination.id,
            title: Kind.archive.title,
            oldValue: String(localized: "Submitted", comment: "kind:pill"),
            newValue: String(localized: "Archived", comment: "kind:pill"),
            requests: [PushRequest(method: .patch, path: "\(Self.path)/\(nomination.id)", body: NominationRequestBody.archive(id: nomination.id))],
            createdAt: now
        )
        change.groupNote = String(localized: "Archive. It stays in App Store Connect, read-only.", comment: "kind:description")
        return change
    }

    /// "Delete the draft": `DELETE`, for a draft App Store Connect has.
    func delete(_ nomination: Nomination, now: Date = .now) -> PendingChange {
        var change = PendingChange(
            id: Self.changeID(.delete, nominationID: nomination.id),
            appID: appID,
            section: .nominations,
            group: group(nomination),
            groupID: nomination.id,
            title: Kind.delete.title,
            oldValue: String(localized: "Draft", comment: "kind:pill"),
            newValue: String(localized: "Deleted", comment: "kind:other"),
            requests: [PushRequest(method: .delete, path: "\(Self.path)/\(nomination.id)")],
            createdAt: now
        )
        change.groupNote = String(localized: "Delete the draft from App Store Connect.", comment: "kind:description")
        return change
    }

    // MARK: - Words

    private func group(_ nomination: Nomination) -> String {
        String(localized: "Nominations · \(nomination.displayName)", comment: "kind:section-title")
    }

    /// "Draft · App Enhancements · from Dec 3, 2026".
    static func summary(_ content: NominationContent) -> String {
        var parts = [String(localized: "Draft", comment: "kind:pill")]
        if let type = content.type { parts.append(type.title) }
        if let start = content.publishStart {
            parts.append(String(localized: "from \(start.formatted(date: .abbreviated, time: .omitted))", comment: "kind:other"))
        }
        return parts.joined(separator: " · ")
    }
}
