//
//  AutoReplyTopic.swift
//  Atlas
//

import Foundation

/// What a review can be about that always waits for the person, read by
/// Claude in any language (board 58).
enum AutoReplyTopic: String, Codable, CaseIterable, Hashable, Sendable {
    case bug
    case billing
    case account
    case featureRequest
    case personal

    var title: String {
        switch self {
        case .bug: String(localized: "A bug or crash")
        case .billing: String(localized: "Billing or a refund")
        case .account: String(localized: "Their account or data")
        case .featureRequest: String(localized: "A feature request")
        case .personal: String(localized: "Something personal")
        }
    }

    /// "it mentions a crash": the reason a reply waits.
    var reason: String {
        switch self {
        case .bug: String(localized: "it mentions a bug or crash")
        case .billing: String(localized: "it’s about billing or a refund")
        case .account: String(localized: "it’s about their account or data")
        case .featureRequest: String(localized: "it asks for a feature")
        case .personal: String(localized: "it’s personal")
        }
    }

    /// The name assistants send in `waitTopics`.
    var key: String { rawValue }
}
