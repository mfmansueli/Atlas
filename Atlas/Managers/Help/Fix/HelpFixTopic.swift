//
//  HelpFixTopic.swift
//  Atlas
//

import Foundation

/// A heading of Help's Fix a problem article (`help-fix.md`), where an
/// error's Fix a Problem link lands: one per kind of thing that goes wrong.
enum HelpFixTopic: String, CaseIterable, Hashable, Sendable {
    case keyRefused
    case cantReadSales
    case pushStopped
    case offline
    case assistant
    case notAllowed
    case notFound
    case refused
    case hourlyLimit
    case appleDown

    /// Fix a problem's article ID.
    static let articleID = "fix"

    /// The heading in the article, word for word.
    var heading: String {
        switch self {
        case .keyRefused: String(localized: "The key was refused", comment: "kind:section-title")
        case .cantReadSales: String(localized: "Atlas can’t read sales", comment: "kind:section-title")
        case .pushStopped: String(localized: "A push stopped halfway", comment: "kind:section-title")
        case .offline: String(localized: "Apple can’t be reached", comment: "kind:section-title")
        case .assistant: String(localized: "An assistant won’t connect", comment: "kind:section-title")
        case .notAllowed: String(localized: "The key can’t do that", comment: "kind:section-title")
        case .notFound: String(localized: "Apple can’t find it", comment: "kind:section-title")
        case .refused: String(localized: "Apple refused a change", comment: "kind:section-title")
        case .hourlyLimit: String(localized: "Apple’s hourly limit was reached", comment: "kind:section-title")
        case .appleDown: String(localized: "Apple didn’t answer", comment: "kind:section-title")
        }
    }

    /// The heading for an error from Apple or the network; nil for a
    /// cancellation and for Atlas's own errors, which say what to do.
    init?(error: any Error) {
        if let error = error as? AppStoreConnectError {
            self = Self.topic(for: error)
        } else if let error = error as? URLError {
            self = AppleErrorCopy.offlineCodes.contains(error.code) ? .offline : .appleDown
        } else {
            return nil
        }
    }

    static func topic(for error: AppStoreConnectError) -> HelpFixTopic {
        switch error {
        case .invalidPrivateKey, .unauthorized: .keyRefused
        case .forbidden: .notAllowed
        case .notFound: .notFound
        case .rateLimited: .hourlyLimit
        case .rejected: .refused
        case let .server(statusCode, _, _) where statusCode >= 500: .appleDown
        case .server: .refused
        case .invalidResponse, .unexpectedPayload: .appleDown
        }
    }

    /// The heading a banner's kind always means: only being offline. An
    /// API error's depends on the error, and the other kinds also report
    /// things that aren't Apple's (a translation service's limit, renders
    /// that fail their checks).
    init?(banner: BannerKind) {
        guard banner == .offline else { return nil }
        self = .offline
    }
}
