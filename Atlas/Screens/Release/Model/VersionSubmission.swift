//
//  VersionSubmission.swift
//  Atlas
//

import Foundation

/// A review submission of the app: the version and what goes to App
/// Review with it.
struct VersionSubmission: Identifiable, Hashable, Sendable {
    var id: String
    /// `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, `IN_REVIEW`,
    /// `UNRESOLVED_ISSUES`, …
    var state: String
    var submitted: Date?
    /// The version it carries, when it carries one.
    var versionID: String?
    /// The In-App Events in it.
    var eventIDs: [String] = []
    /// Each event's item in it, by event id: what a draft loses when the
    /// event is unticked.
    var eventItemIDs: [String: String] = [:]

    /// Made but not sent: items can still be added.
    var isOpen: Bool { state == "READY_FOR_REVIEW" }

    /// App Review sent something back and waits for an answer.
    var hasUnresolvedIssues: Bool { state == "UNRESOLVED_ISSUES" }

    /// Sent and not reviewed yet: it can still be canceled.
    var canCancel: Bool { state == "WAITING_FOR_REVIEW" }
}
