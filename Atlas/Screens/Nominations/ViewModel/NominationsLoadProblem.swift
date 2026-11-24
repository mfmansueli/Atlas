//
//  NominationsLoadProblem.swift
//  Atlas
//

import Foundation

/// Why Nominations couldn't read App Store Connect: the section's one
/// banner. Drafts on this Mac still show below it.
enum NominationsLoadProblem: Hashable, Sendable {
    /// The key's role can't read or create nominations (403).
    case keyRole
    /// No connection: what's queued waits in Review & Push.
    case offline
    /// Anything else, in Atlas's words with Apple's under Details.
    case failed(AppleErrorCopy)

    init(_ error: any Error) {
        if case .forbidden = error as? AppStoreConnectError {
            self = .keyRole
        } else if let error = error as? URLError, Self.offlineCodes.contains(error.code) {
            self = .offline
        } else {
            self = .failed(AppleErrorCopy(String(localized: "Nominations didn’t load.", comment: "kind:error"), error: error))
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff,
    ]
}
