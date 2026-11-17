//
//  ReviewSubmissionItemAttributes.swift
//  Atlas
//

import Foundation

/// A `reviewSubmissionItems` resource: one thing in a submission (a
/// version, an In-App Event…), named by its relationships.
struct ReviewSubmissionItemAttributes: Decodable, Sendable {
    /// `READY_FOR_REVIEW`, `ACCEPTED`, `APPROVED`, `REJECTED` or `REMOVED`.
    var state: String?
}
