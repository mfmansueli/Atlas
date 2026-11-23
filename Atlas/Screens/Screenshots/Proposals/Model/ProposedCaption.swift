//
//  ProposedCaption.swift
//  Atlas
//

import Foundation

/// A caption an assistant suggested that nobody accepted or dismissed yet:
/// one caption of a waiting caption proposal, as the Screenshots language
/// page, its badges and Accept All count it. When two proposals suggest the
/// same slot, only the newest one counts.
struct ProposedCaption: Identifiable, Hashable, Sendable {
    var proposalID: String
    var item: CaptionProposalItem
    /// "Claude Code".
    var client: String
    /// The proposal's why.
    var reason: String
    var receivedAt: Date
    /// The proposal's details and how sure, with this caption's gloss.
    var layers: SuggestionLayers?

    var id: String { Self.makeID(proposalID: proposalID, key: item.key) }

    var locale: String { item.locale }
    var slot: Int { item.slot }
    var key: LocaleSlot { item.key }

    var source: SuggestionSource { .assistant(client: client) }

    /// "Screenshot 2 · caption".
    var title: String {
        String(localized: "Screenshot \(slot + 1) · caption")
    }

    static func makeID(proposalID: String, key: LocaleSlot) -> String {
        "\(proposalID)|\(key.locale)|\(key.slot)"
    }
}
