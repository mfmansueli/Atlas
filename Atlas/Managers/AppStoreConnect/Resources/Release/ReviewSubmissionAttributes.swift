//
//  ReviewSubmissionAttributes.swift
//  Atlas
//

import Foundation

/// A `reviewSubmissions` resource: what went, or is going, to App Review
/// together.
struct ReviewSubmissionAttributes: Decodable, Sendable {
    var platform: String?
    var submittedDate: String?
    /// `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, `IN_REVIEW`,
    /// `UNRESOLVED_ISSUES`, `CANCELING`, `COMPLETING` or `COMPLETE`.
    var state: String?
}
