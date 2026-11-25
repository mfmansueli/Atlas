//
//  PricingStrategySuggestion.swift
//  Atlas
//

import Foundation

/// A pricing strategy or mode an assistant suggested for one app
/// (`propose_pricing_strategy`). It's Atlas's own setting, not App Store
/// Connect's, so it waits on Pricing as a card until the person accepts or
/// dismisses it; nothing changes before, and nothing is pushed.
struct PricingStrategySuggestion: Identifiable, Hashable, Codable, Sendable {
    var id: String
    /// The mode to switch to; nil keeps the app's mode.
    var mode: PricingMode?
    /// The whole strategy after the suggestion; nil keeps the app's.
    var strategy: PricingStrategy?
    /// What changes, at most 8 words ("Price Europe at 90%").
    var title: String
    /// The strongest evidence, one sentence.
    var why: String
    var layers: SuggestionLayers?
    /// Who suggested it, e.g. "Claude Code".
    var source: String
    var receivedAt: Date

    /// Whether accepting it changes anything for an app now set to
    /// `mode` and `strategy`.
    func changes(mode current: PricingMode, strategy now: PricingStrategy) -> Bool {
        (mode.map { $0 != current } ?? false) || (strategy.map { $0 != now } ?? false)
    }
}
