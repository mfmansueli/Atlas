//
//  PushRequestPlaceholderError.swift
//  Atlas
//

import Foundation

/// Why a request's placeholders couldn't be filled in when it was sent
/// (`PushRequest+Placeholders.swift`). The push shows it on the change's
/// progress row, and the change stays queued.
enum PushRequestPlaceholderError: LocalizedError, Equatable {
    /// The request uses `{createdID}`, but no earlier `POST` of the change
    /// returned an ID.
    case missingCreatedID
    /// The named secret isn't in this Mac's Keychain any more.
    case missingSecret(String)

    var errorDescription: String? {
        switch self {
        case .missingCreatedID:
            String(localized: "App Store Connect sent no ID, so the next step wasn’t sent. Refresh, then retry.")
        case .missingSecret:
            String(localized: "Keychain no longer has this change’s password. Enter it again.")
        }
    }
}
