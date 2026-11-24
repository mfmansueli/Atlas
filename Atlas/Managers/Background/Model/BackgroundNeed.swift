//
//  BackgroundNeed.swift
//  Atlas
//

import Foundation

/// One line under "Needs you" in the menu bar's menu: "6 reviews need a
/// reply", "Replies are suggested in each language". Clicking it opens
/// Atlas at `destination`.
struct BackgroundNeed: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    var destination: BackgroundDestination
    /// Something suggested (a finding, a suggestion to review) rather than
    /// something waiting for the person: the Dock count leaves it out.
    var isSuggestion = false
    /// The line's symbol in the menu's symbol column (board 46 after the SF
    /// Symbols pass); nil keeps the slot empty.
    var systemImage: String?

    var needsYou: Bool { !isSuggestion }
}
