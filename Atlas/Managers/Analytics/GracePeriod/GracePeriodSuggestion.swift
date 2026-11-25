//
//  GracePeriodSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's suggestion to turn on Billing Grace Period
/// (`propose_grace_period`). It shows in Analytics → Subscriptions →
/// Billing and Plans; the person turns it on there, after the confirmation
/// that opens with the suggested length.
struct GracePeriodSuggestion: Identifiable, Hashable, Sendable {
    var id = UUID()
    var appID: StoreApp.ID
    var duration: GracePeriodSetting.Duration
    /// Why, at most 110 characters.
    var why: String
    /// e.g. "Claude Code".
    var client: String
    /// How sure the assistant is, and details on demand.
    var layers: SuggestionLayers?
    var receivedAt = Date.now
}
