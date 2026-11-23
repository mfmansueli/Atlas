//
//  ScreenshotHandArrangement.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to delete screenshots from a language's set
/// on one device (`propose_screenshot_removal`) or to put the set in a new
/// order (`propose_screenshot_order`): shown on the Screenshots language
/// page beside the suggested files and captions, to accept or dismiss.
/// Accepting does what Delete… or ◀ ▶ do by hand, so a screenshot Atlas
/// makes from the template leaves only this language's set (or moves in
/// it) while the template keeps its slots everywhere else.
struct ScreenshotHandArrangement: Codable, Hashable, Sendable, Identifiable {
    enum Action: String, Codable, Hashable, Sendable {
        /// `places` go when the person pushes.
        case removal
        /// `places` are every screenshot that stays, in the new order.
        case order
    }

    var id: String
    /// "Claude Code".
    var client: String
    var receivedAt: Date
    var locale: String
    var displayType: ScreenshotDisplayType
    var action: Action
    var places: [ScreenshotHandPlace]
    /// The assistant's why.
    var reason: String
    var evidence: [SuggestionEvidence] = []
    var status: ScreenshotProposalStatus = .waiting
    var decidedAt: Date?

    var isWaiting: Bool { status == .waiting }

    var source: ChangeSource { .assistant(client: client) }

    /// "2 and 4", or for an order "3, 1, 2, 4, 5": the places as they were
    /// numbered when it was sent, from 1.
    var numbers: String {
        let numbers = places.map { String($0.position + 1) }
        return action == .removal ? numbers.formatted(.list(type: .and)) : numbers.joined(separator: ", ")
    }

    // MARK: - Applying

    /// Why it can't be applied to a set.
    enum Problem: Error, Hashable, Sendable {
        /// A screenshot it names isn't in the set any more, or (for an
        /// order) the set has others it doesn't name.
        case changed
        /// It would leave the primary language with no screenshot, which
        /// Apple refuses.
        case lastPrimary
        /// Nothing would change.
        case unchanged
    }

    /// `set` with the screenshots deleted or put in the new order, as the
    /// language page's Delete… and ◀ ▶ do. `isPrimary`: the set is the
    /// primary language's, which must keep one.
    func applied(to set: ScreenshotHandSet, isPrimary: Bool) -> Result<ScreenshotHandSet, Problem> {
        let kept = set.kept
        var ids: [String] = []
        for place in places {
            guard let slot = kept.first(where: { place.matches($0) && !ids.contains($0.id) }) else { return .failure(.changed) }
            ids.append(slot.id)
        }
        var changed = set
        switch action {
        case .removal:
            guard !ids.isEmpty else { return .failure(.unchanged) }
            if isPrimary, kept.count - ids.count < 1 { return .failure(.lastPrimary) }
            for id in ids {
                changed.delete(id)
            }
        case .order:
            guard ids.count == kept.count else { return .failure(.changed) }
            guard ids != kept.map(\.id) else { return .failure(.unchanged) }
            changed.arrange(ids)
        }
        return .success(changed)
    }
}
