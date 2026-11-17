//
//  EngagementState.swift
//  Atlas
//

import Foundation

/// Whether Apple's analytics reports (impressions, page views, downloads)
/// have arrived.
enum EngagementState: Hashable, Sendable {
    case ready
    /// Asked for; Apple hasn't delivered the first report.
    case waiting(asked: Date?)
}
