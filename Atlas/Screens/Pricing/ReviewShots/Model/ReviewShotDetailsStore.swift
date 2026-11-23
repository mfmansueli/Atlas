//
//  ReviewShotDetailsStore.swift
//  Atlas
//

import Foundation
import Observation

/// The details of each review screenshot waiting in Review & Push, by its
/// change's id, kept on this Mac so a suggestion still says what it shows
/// after Atlas restarts. A change that left the queue takes its details
/// with it (`prune`).
@MainActor
@Observable
final class ReviewShotDetailsStore {
    static let shared = ReviewShotDetailsStore(defaults: liveDefaults)

    /// `UserDefaults` key.
    static let key = "reviewShotDetails"

    private(set) var details: [PendingChange.ID: ReviewShotDetails] = [:]
    /// Nil keeps them in memory (tests, DEBUG scenes).
    @ObservationIgnored private let defaults: UserDefaults?

    /// This Mac's defaults, but never the person's in the unit tests' host.
    static var liveDefaults: UserDefaults? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return .standard
    }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.key), let saved = try? JSONDecoder().decode([String: ReviewShotDetails].self, from: data) {
            details = saved
        }
    }

    func details(for id: PendingChange.ID) -> ReviewShotDetails? {
        details[id]
    }

    func set(_ value: ReviewShotDetails?, for id: PendingChange.ID) {
        details[id] = value
        save()
    }

    /// Forgets the details of changes no longer in `ids`.
    func prune(keeping ids: Set<PendingChange.ID>) {
        let kept = details.filter { ids.contains($0.key) }
        guard kept.count != details.count else { return }
        details = kept
        save()
    }

    private func save() {
        guard let defaults, let data = try? JSONEncoder().encode(details) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
