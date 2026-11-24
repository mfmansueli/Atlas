//
//  PageShotsLookCandidate.swift
//  Atlas
//

import Foundation

/// One of the three looks the assistant drew for a page's set, as an
/// Atlas template (propose_page_look).
struct PageShotsLookCandidate: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// "Quiet Indigo".
    var name: String
    /// Why, in a sentence the person reads.
    var rationale: String
    var template: ScreenshotTemplate
    /// Where to refine it, e.g. the Claude Design project.
    var link: String?
    /// Who drew it: "Claude Code".
    var source: String
    var receivedAt: Date
    /// Details and how sure, beside the rationale; nil when none came and
    /// in looks saved before.
    var layers: SuggestionLayers?
}
