//
//  InAppEventQueuedTexts.swift
//  Atlas
//

import Foundation

/// One language's texts of an event waiting in Review & Push: a new
/// language (one change with all its texts, `….<locale>.new`) or edits to
/// a language the event has (a change per text, `….<locale>.<field>`).
struct InAppEventQueuedTexts: Hashable, Sendable, Identifiable {
    var locale: String
    var changeIDs: [String]
    /// The push creates the language.
    var isNewLanguage: Bool
    var texts: [InAppEventField: String]
    var sources: [ChangeSource]
    /// An assistant's change the person hasn't accepted yet.
    var isAwaitingAcceptance: Bool

    var id: String { locale }

    /// The language has all three texts once these are pushed over what
    /// App Store Connect has (`localization`, nil for a new language).
    func completes(_ localization: InAppEventLocalization?) -> Bool {
        InAppEventField.allCases.allSatisfy { field in
            !(texts[field] ?? localization?.text(field) ?? "").isEmpty
        }
    }
}
