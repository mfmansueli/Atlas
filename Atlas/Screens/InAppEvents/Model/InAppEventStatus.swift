//
//  InAppEventStatus.swift
//  Atlas
//

import Foundation

/// An event's status as its row and header say it.
enum InAppEventStatus: Hashable, Sendable {
    case draft
    /// Goes to App Review with the app's version ("Goes with 1.4").
    case goesWithVersion(String)
    case waitingForReview
    case inReview
    case approved
    case live
    case ended
    case rejected
    case archived

    /// `versionString` is the version the event is ticked to go with.
    init(_ event: InAppEvent, goingWithVersion versionString: String?) {
        switch event.state {
        case .draft, .readyForReview:
            self = versionString.map(InAppEventStatus.goesWithVersion) ?? .draft
        case .waitingForReview: self = versionString.map(InAppEventStatus.goesWithVersion) ?? .waitingForReview
        case .inReview: self = versionString.map(InAppEventStatus.goesWithVersion) ?? .inReview
        case .accepted, .approved: self = .approved
        case .published: self = .live
        case .past: self = .ended
        case .rejected: self = .rejected
        case .archived: self = .archived
        }
    }

    var title: String {
        switch self {
        case .draft: String(localized: "Draft")
        case let .goesWithVersion(version): String(localized: "Goes with \(version)")
        case .waitingForReview: String(localized: "Waiting for Review")
        case .inReview: String(localized: "In Review")
        case .approved: String(localized: "Approved")
        case .live: String(localized: "On the App Store")
        case .ended: String(localized: "Ended")
        case .rejected: String(localized: "Rejected")
        case .archived: String(localized: "Archived")
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .draft: .neutral
        case .goesWithVersion, .waitingForReview, .inReview: .accent
        case .approved, .live: .decrease
        case .ended, .archived: .outline
        case .rejected: .danger
        }
    }
}
