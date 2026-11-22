//
//  CaptureStaleness.swift
//  Atlas
//

import Foundation

/// Why a capture is out of date: the assistant saw the app change under it
/// (`mark_captures_stale`, Alba's Japanese phrases rewritten in d038b58).
/// Screenshots → Captures labels it "Out of date" until a new capture
/// takes its place.
struct CaptureStaleness: Codable, Hashable, Sendable {
    var reason: String
    /// What shows it: a file, a commit.
    var evidence: String?
    /// Who marked it, e.g. "Claude Code".
    var client: String
    var markedAt: Date
}
