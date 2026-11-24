//
//  InAppEventLanguage.swift
//  Atlas
//

import Foundation

/// One language of an event, for its language bar.
struct InAppEventLanguage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// In App Store Connect.
        case written
        /// Written or accepted here, waiting in Review & Push.
        case notPushed
        /// An assistant suggested it; nothing is written.
        case suggested
        /// It's written, and an assistant suggests changing some of its
        /// texts.
        case revision
        /// Nothing yet: people there see the primary language.
        case missing
    }

    /// An App Store locale code.
    var code: String
    var state: State

    var id: String { code }

    var locale: StoreLocale? { StoreLocaleCatalog.locale(code: code) }

    var name: String { locale?.name ?? code }

    var isRightToLeft: Bool { locale?.isRTL ?? false }
}
