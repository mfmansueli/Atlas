//
//  ReviewRiskFix.swift
//  Atlas
//

import Foundation

/// How the person fixes a risk: one sentence, the section that does it,
/// and the MCP tool an assistant proposes the fix with, when there is one.
struct ReviewRiskFix: Codable, Hashable, Sendable {
    /// What to do, one sentence: "Add a Terms of Use link to the
    /// description in every language."
    var advice: String
    /// The assistant's tool for it, e.g. "propose_listing_text"; nil when
    /// only the person can do it (App Store Connect, the app's code).
    var tool: String?
    /// Arguments that start the proposal, e.g. the field and locales.
    var arguments: [String: String] = [:]
}
