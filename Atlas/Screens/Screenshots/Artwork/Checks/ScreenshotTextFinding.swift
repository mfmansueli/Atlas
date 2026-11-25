//
//  ScreenshotTextFinding.swift
//  Atlas
//

import Foundation

/// One rule the text in a screenshot breaks, with the words that break it
/// as Vision read them: free and “FREE”.
struct ScreenshotTextFinding: Hashable, Sendable {
    var kind: ScreenshotTextFindingKind
    /// In the order they appear, each once whatever its case.
    var phrases: [String]

    /// “FREE”, “$4.99” and 2 more.
    var quotedPhrases: String {
        StoreTextGuidelineIssue(kind: kind.storeTextKind ?? .pricing, phrases: phrases).quotedPhrases
    }
}
