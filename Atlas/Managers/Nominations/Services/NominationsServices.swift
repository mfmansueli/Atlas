//
//  NominationsServices.swift
//  Atlas
//

import Foundation

/// What Nominations reads: the nominations that include an app (three
/// reads, one per state, as Apple requires a state), and what Atlas knows
/// to suggest from (`NominationContext`). Writes go through Review & Push.
@MainActor
protocol NominationsServices {
    /// Drafts, submitted and archived nominations that include `app`.
    func nominations(for app: StoreApp) async throws -> [Nomination]
    /// The account's apps, the version being prepared, the app's events and
    /// links. Never fails: what can't be read is left out.
    func context(for app: StoreApp) async -> NominationContext
}
