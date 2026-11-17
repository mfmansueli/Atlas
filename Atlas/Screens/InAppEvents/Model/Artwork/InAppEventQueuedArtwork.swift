//
//  InAppEventQueuedArtwork.swift
//  Atlas
//

import Foundation

/// An event card or details page waiting in Review & Push for one
/// language: the file it uploads, who proposed it, and whether the person
/// accepted it yet.
struct InAppEventQueuedArtwork: Hashable, Sendable, Identifiable {
    var changeID: String
    var kind: InAppEventMedia.Kind
    var locale: String
    var push: InAppEventArtworkPush
    var source: ChangeSource
    var isAwaitingAcceptance: Bool

    var id: String { changeID }
}
