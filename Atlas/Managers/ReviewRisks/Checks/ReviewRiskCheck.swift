//
//  ReviewRiskCheck.swift
//  Atlas
//

import Foundation

/// One App Review check: a plain function of the facts, so it runs the
/// same in the MCP tool, Look for Improvements, the Submit sheet and a
/// unit test. A check whose facts are missing says why instead of
/// finding nothing.
protocol ReviewRiskCheck: Sendable {
    var id: ReviewRiskCheckID { get }
    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome
}
