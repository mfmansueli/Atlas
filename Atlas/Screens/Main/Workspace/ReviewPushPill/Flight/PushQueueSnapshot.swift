//
//  PushQueueSnapshot.swift
//  Atlas
//

import Foundation

/// What waits in Review & Push, as its pill counts it: the queue's changes
/// (and which of them still wait to be accepted), the screenshots and the
/// extras. Comparing two tells what just joined, for the chip that flies
/// there (`PushFlightCenter.queueChanged`).
struct PushQueueSnapshot: Equatable, Sendable {
    /// Each change's id and name.
    var changes: [PendingChange.ID: String] = [:]
    /// The assistant's proposals still waiting to be accepted.
    var awaiting: Set<PendingChange.ID> = []
    var imageCount = 0
    /// Each extra by app and id, with its name.
    var extras: [String: String] = [:]

    init(changes: [PendingChange.ID: String] = [:], awaiting: Set<PendingChange.ID> = [], imageCount: Int = 0, extras: [String: String] = [:]) {
        self.changes = changes
        self.awaiting = awaiting
        self.imageCount = imageCount
        self.extras = extras
    }

    init(changes: [PendingChange], imageCount: Int, extras: [ExtrasReviewItem]) {
        self.changes = Dictionary(changes.map { ($0.id, PushFlightLabel.name(of: $0)) }) { first, _ in first }
        awaiting = Set(changes.filter { $0.awaitingAcceptance != nil }.map(\.id))
        self.imageCount = imageCount
        self.extras = Dictionary(extras.map { ("\($0.appID)/\($0.id)", PushFlightLabel.name(of: $0)) }) { first, _ in first }
    }

    /// What the pill counts.
    var count: Int { changes.count + imageCount + extras.count }

    /// The names of what joined since `old`: new changes, proposals
    /// accepted now and new extras, in a stable order.
    func joinedLabels(since old: PushQueueSnapshot) -> [String] {
        let added = changes.filter { old.changes[$0.key] == nil }
        let accepted = changes.filter { old.awaiting.contains($0.key) && !awaiting.contains($0.key) }
        let extrasAdded = extras.filter { old.extras[$0.key] == nil }
        let named = added.merging(accepted) { first, _ in first }
        return named.sorted { $0.key < $1.key }.map(\.value) + extrasAdded.sorted { $0.key < $1.key }.map(\.value)
    }

    /// Screenshots that joined since `old`.
    func joinedImages(since old: PushQueueSnapshot) -> Int {
        max(0, imageCount - old.imageCount)
    }
}
