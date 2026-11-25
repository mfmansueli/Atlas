//
//  ReviewRiskVerdict.swift
//  Atlas
//

import Foundation

/// An assistant's word on a check that needs the project: it read the
/// code and the risk is there (confirmed) or isn't (cleared), with where.
struct ReviewRiskVerdict: Codable, Hashable, Sendable {
    var check: ReviewRiskCheckID
    var riskID: String
    /// The assistant that said it, e.g. "Claude Code".
    var author: String
    /// Where in the project, e.g. "Settings/AccountView.swift:88".
    var evidence: String
    var date: Date
}
