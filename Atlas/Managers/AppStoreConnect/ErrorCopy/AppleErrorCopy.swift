//
//  AppleErrorCopy.swift
//  Atlas
//

import Foundation

/// An error from Apple (App Store Connect, the network, or a system
/// framework) in Atlas's words: what happened and what to do, with Apple's
/// own text kept apart for Details. Apple's text is never the message.
///
/// Build one with the place's "what happened" sentence, e.g.
/// `AppleErrorCopy(String(localized: "Prices didn’t load."), error: error)`
/// gives "Prices didn’t load. Try again in a minute." with "HTTP 503" in
/// `details`.
struct AppleErrorCopy: Equatable, Hashable, Sendable {
    /// "Prices didn’t load. Try again in a minute."
    let summary: String
    /// Apple's own words and code, shown only on demand. Nil when Apple
    /// said nothing more than the summary does.
    let details: String?

    init(summary: String, details: String?) {
        self.summary = summary
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// `what` is the place's "what happened" sentence ("Analytics didn’t
    /// load."); the next step comes from the kind of error.
    init(_ what: String, error: any Error) {
        let step = Self.nextStep(for: error)
        let summary = step.map { "\(what) \($0)" } ?? what
        self.init(summary: summary, details: Self.details(for: error))
    }

    /// For a place that can only show one string: the summary, then Apple's
    /// text on its own line after "Details:".
    var text: String {
        guard let details else { return summary }
        return String(localized: "\(summary)\nDetails: \(details)", comment: "kind:error")
    }

    // MARK: - What to do

    /// The second sentence of the summary, by kind of error. Nil when the
    /// error itself already says what to do (Atlas's own errors).
    static func nextStep(for error: any Error) -> String? {
        if let error = error as? AppStoreConnectError {
            return appStoreConnectStep(for: error)
        }
        if let error = error as? URLError {
            return networkStep(for: error)
        }
        if error is CancellationError {
            return nil
        }
        return String(localized: "Try again.", comment: "kind:error")
    }

    static func appStoreConnectStep(for error: AppStoreConnectError) -> String {
        switch error {
        case .invalidPrivateKey:
            String(localized: "Choose the AuthKey .p8 file from App Store Connect.", comment: "kind:error")
        case .unauthorized:
            String(localized: "Apple refused this key. Check it in Settings → Accounts.", comment: "kind:error")
        case .forbidden:
            String(localized: "This key can’t do that. Use an Admin or App Manager key.", comment: "kind:error")
        case .notFound:
            String(localized: "Apple can’t find it anymore. Refresh and try again.", comment: "kind:error")
        case .rateLimited:
            String(localized: "Apple’s hourly limit was reached. Try again in a few minutes.", comment: "kind:error")
        case .rejected:
            String(localized: "Apple refused the change. See Details.", comment: "kind:error")
        case let .server(statusCode, _, _) where statusCode >= 500:
            String(localized: "Apple didn’t answer. Try again in a minute.", comment: "kind:error")
        case .server:
            String(localized: "Apple refused the request. See Details.", comment: "kind:error")
        case .invalidResponse, .unexpectedPayload:
            String(localized: "Apple’s answer couldn’t be read. Try again in a minute.", comment: "kind:error")
        }
    }

    static func networkStep(for error: URLError) -> String {
        if offlineCodes.contains(error.code) {
            return String(localized: "Atlas can’t reach Apple. Check your connection and try again.", comment: "kind:error")
        }
        return String(localized: "Try again in a minute.", comment: "kind:error")
    }

    // MARK: - Details

    /// Apple's text and code: "ENTITY_ERROR.ATTRIBUTE.INVALID — The price
    /// point is not available", "HTTP 503", or the system's description.
    static func details(for error: any Error) -> String? {
        if let error = error as? AppStoreConnectError {
            switch error {
            case .rejected, .server, .forbidden, .notFound:
                return error.pushFailureText
            case .unauthorized:
                return "HTTP 401"
            case .rateLimited:
                return "HTTP 429"
            case .invalidPrivateKey, .invalidResponse, .unexpectedPayload:
                return error.errorDescription
            }
        }
        if error is CancellationError {
            return nil
        }
        if let error = error as? URLError {
            return "\(error.localizedDescription) (URLError \(error.code.rawValue))"
        }
        let nsError = error as NSError
        return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
    }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut,
        .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed,
    ]
}
