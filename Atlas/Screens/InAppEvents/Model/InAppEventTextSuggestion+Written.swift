//
//  InAppEventTextSuggestion+Written.swift
//  Atlas
//

import Foundation

// A suggestion App Store Connect caught up with: its language was written
// since it was made (in App Store Connect, or by a push). Alba, Nov 19:
// Claude Code's 13 new languages of "New Year, New Mindset" waited after
// all 14 were written, hidden on the event's page but counted on the
// sidebar. Each read of the events settles them: done when App Store
// Connect has every text it suggests, else a revision of the texts that
// differ, for the person to accept or dismiss.
extension InAppEventTextSuggestion {
    /// The suggestion once `event` is as App Store Connect has it: itself
    /// while it still adds something, nil when App Store Connect has every
    /// text it suggests (done), and for a new language's texts whose
    /// language is written now, a revision of the texts that differ, its
    /// why saying it came before.
    func caughtUp(with event: InAppEvent) -> InAppEventTextSuggestion? {
        guard event.id == eventID, isStale(in: event), let localization = event.localization(locale) else { return self }
        // A revision is stale once every text it changes is there.
        guard !isRevision else { return nil }
        let differing = InAppEventField.allCases.filter { field in
            let suggested = Self.normalized(text(field))
            return !suggested.isEmpty && suggested != Self.normalized(localization.text(field))
        }
        guard !differing.isEmpty else { return nil }
        var revision = self
        revision.revisedFields = differing
        for field in InAppEventField.allCases where !differing.contains(field) {
            revision.setText("", for: field)
        }
        revision.why = Self.suggestedBeforeWritten(why)
        return revision
    }

    /// "Suggested before this language was written: In Brazil December is
    /// summer…".
    static func suggestedBeforeWritten(_ why: String) -> String {
        let reason = why.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return String(localized: "Suggested before this language was written.") }
        return String(localized: "Suggested before this language was written: \(reason)")
    }

    private mutating func setText(_ text: String, for field: InAppEventField) {
        switch field {
        case .name: name = text
        case .shortDescription: shortDescription = text
        case .longDescription: longDescription = text
        }
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
