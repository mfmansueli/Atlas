//
//  NewProductPage.swift
//  Atlas
//

import Foundation

/// What the New Product Page sheet collects: a name, what it starts from,
/// who it's for (a note for the assistant) and the languages with their
/// own content.
struct NewProductPage: Hashable, Sendable {
    var name = ""
    var start: ProductPageStart = .defaultPage
    var note = ""
    var locales: [String] = []

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Why Create Page is off: no name, a name another page has, or no
    /// language.
    func problem(existingNames: [String]) -> String? {
        if trimmedName.isEmpty { return String(localized: "Give the page a name.") }
        if existingNames.contains(where: { $0.compare(trimmedName, options: [.caseInsensitive]) == .orderedSame }) {
            return String(localized: "Another page is called “\(trimmedName)”.")
        }
        if locales.isEmpty { return String(localized: "Choose at least one language with its own content.") }
        return nil
    }

    func draft(id: ProductPageDraft.ID, now: Date) -> ProductPageDraft {
        ProductPageDraft(
            id: id, name: trimmedName, start: start, note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            locales: locales, createdAt: now
        )
    }
}
