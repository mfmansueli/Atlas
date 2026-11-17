//
//  InAppEventArtworkProposal.swift
//  Atlas
//

import Foundation

/// One file proposed as an event's card or details page, with every
/// language it goes into: what the media card shows once, with one Accept
/// and one Dismiss.
struct InAppEventArtworkProposal: Hashable, Sendable, Identifiable {
    var kind: InAppEventMedia.Kind
    var push: InAppEventArtworkPush
    var items: [InAppEventQueuedArtwork]

    var id: String { "\(kind.rawValue) \(push.path)" }
    var source: ChangeSource { items.first?.source ?? .you }
    var isAwaitingAcceptance: Bool { items.contains(where: \.isAwaitingAcceptance) }
    var locales: [String] { items.map(\.locale) }

    /// The queued art of an event as one proposal per kind and file, the
    /// card first.
    static func grouped(_ items: [InAppEventQueuedArtwork]) -> [InAppEventArtworkProposal] {
        var proposals: [InAppEventArtworkProposal] = []
        for item in items {
            if let index = proposals.firstIndex(where: { $0.kind == item.kind && $0.push.path == item.push.path }) {
                proposals[index].items.append(item)
            } else {
                proposals.append(InAppEventArtworkProposal(kind: item.kind, push: item.push, items: [item]))
            }
        }
        return proposals
    }

    /// "English (U.S.), German and 3 more".
    var localesText: String {
        let names = locales.map { InAppEventChangeBuilder.localeName($0) }
        guard names.count > 3 else { return names.formatted(.list(type: .and)) }
        return String(localized: "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) more")
    }
}
