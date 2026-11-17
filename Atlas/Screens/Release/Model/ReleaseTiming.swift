//
//  ReleaseTiming.swift
//  Atlas
//

import Foundation

/// What happens when App Review approves the version.
enum ReleaseTiming: Hashable, Sendable {
    /// Apple releases it right away.
    case afterApproval
    /// It waits for the person's Release Now.
    case manual
    /// Apple releases it on a date, not before.
    case scheduled(Date)

    init(releaseType: String?, earliestReleaseDate: Date?) {
        switch releaseType {
        case "MANUAL": self = .manual
        case "SCHEDULED": self = earliestReleaseDate.map(ReleaseTiming.scheduled) ?? .afterApproval
        default: self = .afterApproval
        }
    }

    /// `AFTER_APPROVAL`, `MANUAL` or `SCHEDULED`.
    var releaseType: String {
        switch self {
        case .afterApproval: "AFTER_APPROVAL"
        case .manual: "MANUAL"
        case .scheduled: "SCHEDULED"
        }
    }

    var date: Date? {
        if case let .scheduled(date) = self { return date }
        return nil
    }

    /// The picker's three choices, whatever date is chosen.
    enum Kind: String, CaseIterable, Identifiable, Hashable, Sendable {
        case afterApproval
        case manual
        case scheduled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .afterApproval: String(localized: "Release right after approval")
            case .manual: String(localized: "I’ll release it myself")
            case .scheduled: String(localized: "Release on a date")
            }
        }
    }

    var kind: Kind {
        switch self {
        case .afterApproval: .afterApproval
        case .manual: .manual
        case .scheduled: .scheduled
        }
    }
}
