//
//  ProductPageTextRefusal.swift
//  Atlas
//

import Foundation

/// Why Atlas didn't offer an assistant's promotional text: the rules it
/// breaks, said once for the person ("Not offered") and once for the
/// assistant, which is asked for another.
enum ProductPageTextRefusal {
    /// "It says “free” and names another platform. App Review rejects
    /// promotional text with prices, offers or other platforms, so Atlas
    /// doesn’t offer it to accept."
    static func reason(for issues: [StoreTextGuidelineIssue]) -> String {
        guard !issues.isEmpty else { return "" }
        let what = issues.map { issue in
            switch issue.kind {
            case .pricing: String(localized: "talks about price or an offer (\(issue.quotedPhrases))")
            case .otherPlatform: String(localized: "names another platform (\(issue.quotedPhrases))")
            default: String(localized: "has \(issue.quotedPhrases), which App Review doesn’t allow")
            }
        }
        return String(localized: """
        It \(what.formatted(.list(type: .and))). App Review rejects this in promotional text, so it’s not offered.
        """)
    }

    /// For the assistant: each rule, and what to write instead.
    static func assistantReason(for issues: [StoreTextGuidelineIssue]) -> String {
        issues.map(\.assistantReason).joined(separator: " ")
    }
}
