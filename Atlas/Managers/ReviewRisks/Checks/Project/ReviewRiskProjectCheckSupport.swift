//
//  ReviewRiskProjectCheckSupport.swift
//  Atlas
//

import Foundation

/// What the three project checks share: the reason they can't run, and
/// evidence from code matches.
enum ReviewRiskProjectCheckSupport {
    /// The project facts the checks can read: a folder with Swift files.
    static func readable(_ facts: ReviewRiskFacts) -> ReviewRiskProjectFacts? {
        guard let project = facts.project, project.swiftFileCount > 0 else { return nil }
        return project
    }

    /// Why the checks can't run on `facts`.
    static func unreadableReason(_ facts: ReviewRiskFacts) -> String {
        facts.project == nil ? noProject : noSwiftFiles
    }

    static var noProject: String {
        String(
            localized: "Choose the app’s project folder in Settings → AI Assistants, or ask the assistant to check the code.",
            comment: "kind:error · an App Review check that needs the app's code couldn't run"
        )
    }

    static var noSwiftFiles: String {
        String(
            localized: "Atlas found no Swift files in the project folder. Ask the assistant to check the code.",
            comment: "kind:error · an App Review check that needs the app's code couldn't run"
        )
    }

    /// The first `limit` matches as evidence: "Login/SignUpView.swift:42"
    /// and the line.
    static func evidence(_ matches: [ReviewRiskCodeMatch], limit: Int = 3) -> [ReviewRiskEvidence] {
        matches.prefix(limit).map { ReviewRiskEvidence(place: $0.place, excerpt: $0.excerpt) }
    }

    /// The names in `matches`, once each, in the order found: "Google Sign-In, Facebook Login".
    static func names(_ matches: [ReviewRiskCodeMatch]) -> [String] {
        var seen: Set<String> = []
        return matches.map(\.what).filter { seen.insert($0).inserted }
    }
}
