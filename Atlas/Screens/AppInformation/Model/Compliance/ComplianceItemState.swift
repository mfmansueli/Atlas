//
//  ComplianceItemState.swift
//  Atlas
//

import Foundation

/// Where one regulation stands on the App Compliance page.
enum ComplianceItemState: Hashable, Sendable {
    /// Something only the person can answer.
    case needsAnswer
    /// Answered here. Apple's API can't take it, so it still has to be
    /// entered in App Store Connect.
    case toEnter
    /// Answered with a change that waits in Review & Push.
    case notPushed
    /// Not needed, or Apple shows no problem.
    case passes
}
