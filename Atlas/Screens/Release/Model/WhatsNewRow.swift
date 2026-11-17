//
//  WhatsNewRow.swift
//  Atlas
//

import Foundation

/// One language's What's New in the Submit sheet.
struct WhatsNewRow: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// In App Store Connect.
        case written
        /// Accepted or edited here and not pushed yet.
        case notPushed
        /// Missing, with a suggestion to accept.
        case suggested(FieldSuggestion)
        case missing
    }

    var locale: StoreLocale
    /// The text that would go to App Review; empty when missing.
    var text: String
    var state: State

    var id: String { locale.code }

    /// Nothing to send for this language yet.
    var isMissing: Bool {
        switch state {
        case .written, .notPushed: false
        case .suggested, .missing: true
        }
    }

    var statusTitle: String {
        switch state {
        case .written: String(localized: "Written")
        case .notPushed: String(localized: "Accepted")
        case .suggested: String(localized: "Suggested")
        case .missing: String(localized: "Missing")
        }
    }
}
