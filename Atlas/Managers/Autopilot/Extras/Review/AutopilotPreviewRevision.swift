//
//  AutopilotPreviewRevision.swift
//  Atlas
//

import Foundation

/// One App Preview version from the design source: what the person asked
/// and what changed.
struct AutopilotPreviewRevision: Codable, Hashable, Sendable {
    /// 2, 3…
    var version: Int
    /// "Slower pace, starts with Search".
    var changes: String
    /// What the person asked.
    var note: String
    /// "Claude Code".
    var client: String
    var madeAt: Date
    /// The design source's details and how sure, beside `changes`; nil
    /// when none came and in versions saved before.
    var layers: SuggestionLayers?
}
