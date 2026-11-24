//
//  MCPToolError.swift
//  Atlas
//

import Foundation

/// Why a tool couldn't run. The assistant gets the message as an error
/// result it can act on, and the activity log shows it as refused.
enum MCPToolError: LocalizedError, Equatable {
    /// An argument is missing or has the wrong type.
    case invalidArgument(name: String, expected: String)
    /// No app, product or locale matches what the assistant asked for.
    case notFound(String)
    /// No App Store Connect account is open in Atlas.
    case notConnected
    /// Atlas couldn't read what the tool needs, e.g. the app library
    /// failed to load; the message says why.
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(name, expected):
            String(localized: "The argument “\(name)” must be \(expected).")
        case let .notFound(message), let .unavailable(message):
            message
        case .notConnected:
            String(localized: "Atlas isn’t connected to App Store Connect. Ask the person to open Atlas and connect a key.")
        }
    }
}
