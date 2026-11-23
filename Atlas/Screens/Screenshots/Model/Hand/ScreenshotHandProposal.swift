//
//  ScreenshotHandProposal.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to put a file in place of one screenshot
/// (`propose_screenshot_file`): shown on the language page beside the
/// suggested captions, to accept or dismiss. Deleting or moving
/// screenshots is a `ScreenshotHandArrangement`.
struct ScreenshotHandProposal: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// "Claude Code".
    var client: String
    var receivedAt: Date
    var locale: String
    var displayType: ScreenshotDisplayType
    /// The place it replaces, from 0 among the set's screenshots; nil adds
    /// it after the last one.
    var position: Int?
    var file: ScreenshotHandFile
    /// The assistant's why.
    var reason: String
    var status: ScreenshotProposalStatus = .waiting
    var decidedAt: Date?

    var isWaiting: Bool { status == .waiting }

    var source: ChangeSource { .assistant(client: client) }
}
