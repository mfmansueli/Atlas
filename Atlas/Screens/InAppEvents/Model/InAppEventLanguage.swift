//
//  InAppEventLanguage.swift
//  Atlas
//

import Foundation

/// One language of an event in the language bar.
struct InAppEventLanguage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// In App Store Connect.
        case written
        /// Written or accepted here, waiting in Review & Push.
        case notPushed
        /// An assistant suggested it; nothing is written.
        case suggested
        /// Nothing yet: people there see the primary language.
        case missing
    }

    /// An App Store locale code.
    var code: String
    var state: State

    var id: String { code }

    var locale: StoreLocale? { StoreLocaleCatalog.locale(code: code) }

    var name: String { locale?.name ?? code }

    /// "German", for a chip.
    var shortName: String { locale?.shortName ?? code }

    var isRightToLeft: Bool { locale?.isRTL ?? false }

    /// "German, suggestion to review".
    var accessibilityText: String {
        switch state {
        case .written: name
        case .notPushed: String(localized: "\(name), not pushed")
        case .suggested: String(localized: "\(name), suggestion to review")
        case .missing: String(localized: "\(name), not written")
        }
    }
}
