//
//  DebugReleasePhase.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state a release DEBUG scene starts the version in.
enum DebugReleasePhase: String, CaseIterable, Hashable, Sendable {
    case prepare
    case waiting
    case review
    case pending
    case phased
    case paused
    case rejected
    case live

    /// App Store Connect's version state for it.
    var state: String {
        switch self {
        case .prepare: "PREPARE_FOR_SUBMISSION"
        case .waiting: "WAITING_FOR_REVIEW"
        case .review: "IN_REVIEW"
        case .pending: "PENDING_DEVELOPER_RELEASE"
        case .phased, .paused, .live: "READY_FOR_DISTRIBUTION"
        case .rejected: "REJECTED"
        }
    }
}
#endif
