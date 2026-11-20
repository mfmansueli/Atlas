//
//  InAppEventTextSuggestion.swift
//  Atlas
//

import Foundation

/// One language of an event, suggested by an assistant: all three texts of
/// a language that isn't written yet, or a revision of some texts of one
/// that is (`revisedFields`: "…by Sunday" when the event now ends on a
/// Wednesday), with why they read this way ("In Brazil December is
/// summer…"). It waits for Accept; accepted, the texts wait in Review &
/// Push. A language has one suggestion at a time.
struct InAppEventTextSuggestion: Identifiable, Hashable, Codable, Sendable {
    var eventID: InAppEvent.ID
    /// An App Store locale code, e.g. `pt-BR`.
    var locale: String
    var name: String
    var shortDescription: String
    var longDescription: String
    var why: String
    /// Who suggested it, e.g. "Claude Code".
    var source: String
    var date: Date
    /// The texts a revision changes, in their order; the others stay as
    /// they are (and are empty here). Nil for a new language's three
    /// texts, and for suggestions saved before there were revisions.
    var revisedFields: [InAppEventField]?

    var id: String { "\(eventID).\(locale)" }

    /// A revision of a language that's written, rather than its texts.
    var isRevision: Bool { revisedFields != nil }

    /// The texts it suggests: all three, or a revision's.
    var fields: [InAppEventField] {
        revisedFields ?? InAppEventField.allCases
    }

    /// Whether it suggests `field`'s text.
    func suggests(_ field: InAppEventField) -> Bool {
        fields.contains(field)
    }

    func text(_ field: InAppEventField) -> String {
        switch field {
        case .name: name
        case .shortDescription: shortDescription
        case .longDescription: longDescription
        }
    }

    /// The texts it suggests, by field.
    var texts: [InAppEventField: String] {
        Dictionary(uniqueKeysWithValues: fields.map { ($0, text($0)) })
    }

    /// Accepting it would add nothing or overwrite what's there: App
    /// Store Connect has this language written already (new texts), or
    /// already has every revised text (a revision).
    func isStale(in event: InAppEvent) -> Bool {
        guard let localization = event.localization(locale) else { return false }
        guard isRevision else { return localization.isComplete }
        return fields.allSatisfy { localization.text($0) == text($0) }
    }

    /// The first field over Apple's limit, with its length.
    var overLimit: (field: InAppEventField, count: Int)? {
        fields.lazy.map { ($0, text($0).count) }.first { $0.1 > $0.0.limit }.map { (field: $0.0, count: $0.1) }
    }
}
