//
//  PageShotsDesign.swift
//  Atlas
//

import Foundation

/// The Look a page's set is made with, and the looks drawn for it.
struct PageShotsDesign: Codable, Hashable, Sendable {
    static let candidateCount = 3

    var look: PageShotsLook
    var candidates: [PageShotsLookCandidate] = []
    /// The candidate the person chose (Claude Design).
    var chosenID: String?
    /// The Claude Code session drawing the looks.
    var claudeRunID: UUID?
    var askedAt: Date?
    /// What went wrong drawing them, said calmly.
    var problem: String?

    var chosen: PageShotsLookCandidate? {
        chosenID.flatMap { id in candidates.first { $0.id == id } }
    }

    /// Whether the set can be laid out with this look now: a new look
    /// needs one of the three chosen.
    var isReady: Bool { !look.isClaudeDesign || chosen != nil }
}
