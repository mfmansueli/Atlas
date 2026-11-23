//
//  AppStoreConnectError.swift
//  Atlas
//

import Foundation

/// What can go wrong talking to App Store Connect, with the message the UI
/// shows. HTTP failures carry the first `detail` Apple sent back, if any,
/// followed by the reasons in its associated errors.
enum AppStoreConnectError: LocalizedError, Equatable {
    /// The `.p8` contents aren't a P-256 private key.
    case invalidPrivateKey
    /// 401: wrong issuer ID / key ID pair, a revoked key, or a bad signature.
    case unauthorized
    /// 403: the key's role can't do this.
    case forbidden(detail: String?)
    case notFound(detail: String?)
    /// 429: the hourly request quota is used up.
    case rateLimited
    /// 409 or 422: Apple refused the value, with its error code, e.g.
    /// `ENTITY_ERROR.RELATIONSHIP.INVALID`.
    case rejected(statusCode: Int, code: String?, detail: String?)
    /// Anything else, e.g. 500 with `UNEXPECTED_ERROR`.
    case server(statusCode: Int, code: String? = nil, detail: String?)
    /// Not an HTTP response at all.
    case invalidResponse
    /// A 2xx response whose body isn't what the endpoint documents.
    case unexpectedPayload

    init(statusCode: Int, body: Data) {
        let response = try? JSONDecoder().decode(AppStoreConnectErrorResponse.self, from: body)
        let detail = Self.detail(of: response?.errors.first)
        switch statusCode {
        case 401: self = .unauthorized
        case 403: self = .forbidden(detail: detail)
        case 404: self = .notFound(detail: detail)
        case 409, 422: self = .rejected(statusCode: statusCode, code: response?.errors.first?.code, detail: detail)
        case 429: self = .rateLimited
        default: self = .server(statusCode: statusCode, code: response?.errors.first?.code, detail: detail)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            String(localized: "Can't read this private key. Choose the AuthKey .p8 file from App Store Connect.")
        case .unauthorized:
            String(localized: "App Store Connect rejected this key. Check the Issuer ID, Key ID, and that it isn't revoked.")
        case let .forbidden(detail):
            Self.message(String(localized: "This API key isn't allowed to do that. Team keys need the Admin or App Manager role."), detail: detail)
        case let .notFound(detail):
            Self.message(String(localized: "App Store Connect couldn't find that resource."), detail: detail)
        case .rateLimited:
            String(localized: "App Store Connect's hourly request limit was reached. Try again in a few minutes.")
        case let .rejected(statusCode, code, detail):
            Self.message(String(localized: "App Store Connect refused the change (\(code ?? String(statusCode)))."), detail: detail)
        case let .server(statusCode, _, detail):
            Self.message(String(localized: "App Store Connect had a problem (\(statusCode)). Try again in a minute."), detail: detail)
        case .invalidResponse:
            String(localized: "App Store Connect sent an answer Atlas can’t read. Try again.")
        case .unexpectedPayload:
            String(localized: "App Store Connect sent an unexpected answer. Try again later.")
        }
    }

    /// 409 `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE`: what a `POST` would
    /// create is there already, e.g. a localization for that locale.
    var isDuplicate: Bool {
        guard case let .rejected(_, code, _) = self else { return false }
        return code == "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE"
    }

    /// 409 `ENTITY_ERROR.ATTRIBUTE.INVALID.UNMODIFIABLE`, e.g. a pre-4.4.1
    /// write of a subscription group's texts, which live in versions now.
    var isUnmodifiable: Bool {
        guard case let .rejected(_, code, _) = self else { return false }
        return code == "ENTITY_ERROR.ATTRIBUTE.INVALID.UNMODIFIABLE"
    }

    /// A 5xx, e.g. 500 `UNEXPECTED_ERROR`: Apple's server failed, and the
    /// write may still have been made. A 4xx in `.server` (400
    /// `PARAMETER_ERROR`) was refused outright.
    var isServerFailure: Bool {
        guard case let .server(statusCode, _, _) = self else { return false }
        return statusCode >= 500
    }

    /// 409 `STATE_ERROR`, e.g. "Screenshot Set Already Exists!".
    var isStateError: Bool {
        guard case let .rejected(_, code, _) = self else { return false }
        return code == "STATE_ERROR"
    }

    /// Apple's code and detail as the push progress list shows them:
    /// "ENTITY_ERROR.RELATIONSHIP.INVALID — The price point is not available…".
    var pushFailureText: String {
        switch self {
        case let .rejected(statusCode, code, detail):
            [code ?? "HTTP \(statusCode)", detail].compactMap(\.self).joined(separator: " — ")
        case let .server(statusCode, code, detail):
            [code ?? "HTTP \(statusCode)", detail].compactMap(\.self).joined(separator: " — ")
        case let .forbidden(detail):
            ["FORBIDDEN_ERROR", detail].compactMap(\.self).joined(separator: " — ")
        case let .notFound(detail):
            ["NOT_FOUND", detail].compactMap(\.self).joined(separator: " — ")
        default:
            errorDescription ?? ""
        }
    }

    /// How many associated reasons are listed; the rest are counted.
    static let reasonsShown = 6

    /// Apple's detail, then each reason it gives in `associatedErrors`, one
    /// per line, as Apple words it: "You must provide a value for the
    /// attribute 'copyright' with this request".
    static func detail(of item: AppStoreConnectErrorItem?) -> String? {
        guard let item else { return nil }
        var reasons: [String] = []
        for reason in item.associatedErrors.compactMap(Self.reason) where !reasons.contains(reason) && reason != item.text {
            reasons.append(reason)
        }
        guard !reasons.isEmpty else { return item.text }
        var lines = reasons.prefix(reasonsShown).map { "• \($0)" }
        if reasons.count > reasonsShown { lines.append(String(localized: "and \(reasons.count - reasonsShown) more")) }
        return ([item.text].compactMap(\.self) + lines).joined(separator: "\n")
    }

    /// An associated error's words, naming the In-App Event it's about
    /// ("… (In-App Event 6740000000)"): a review submission's events are
    /// refused one by one, and the person needs to know which.
    static func reason(_ item: AppStoreConnectErrorItem) -> String? {
        guard let text = item.text else { return nil }
        guard let eventID = item.eventID else { return text }
        return "\(text) (\(eventMarker)\(eventID))"
    }

    /// What precedes an event's id in a reason: "In-App Event ".
    static let eventMarker = "In-App Event "

    private static func message(_ summary: String, detail: String?) -> String {
        guard let detail, !detail.isEmpty else { return summary }
        return "\(summary) \(detail)"
    }
}
