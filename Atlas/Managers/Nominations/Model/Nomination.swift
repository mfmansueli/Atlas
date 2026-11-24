//
//  Nomination.swift
//  Atlas
//

import Foundation

/// One nomination: a draft on this Mac, or one App Store Connect has (a
/// draft, submitted or archived), with who made and sent it. Apple reports
/// nothing back after it's submitted.
struct Nomination: Identifiable, Hashable, Codable, Sendable {
    /// App Store Connect's ID, or `local-<uuid>` for a draft on this Mac.
    var id: String
    var state: NominationState = .draft
    var content = NominationContent()
    var createdDate: Date?
    var lastModifiedDate: Date?
    var submittedDate: Date?
    /// Who created it, e.g. "Mateus".
    var createdBy: String?
    /// Who submitted it.
    var submittedBy: String?
    /// The assistant that suggested it, e.g. "Claude Code"; nil for the
    /// person's own.
    var suggestedBy: String?
    /// The apps' names as App Store Connect gave them, by ID.
    var appNames: [String: String] = [:]
    /// The linked events' reference names, by ID.
    var eventNames: [String: String] = [:]

    static let localPrefix = "local-"

    /// A new draft on this Mac for `appID`.
    static func newDraft(appID: StoreApp.ID, now: Date = .now, by person: String? = nil) -> Nomination {
        Nomination(
            id: localPrefix + UUID().uuidString.lowercased(),
            content: NominationContent(appIDs: [appID]),
            createdDate: now,
            createdBy: person
        )
    }

    /// Whether App Store Connect has it; false for a draft on this Mac.
    var isInAppStoreConnect: Bool { !id.hasPrefix(Self.localPrefix) }

    var isEditable: Bool { state.isEditable }

    /// "Untitled nomination" until it has a name.
    var displayName: String {
        content.trimmedName.isEmpty ? String(localized: "Untitled nomination", comment: "kind:empty-state") : content.trimmedName
    }
}
