//
//  FieldSuggestion.swift
//  Atlas
//

import Foundation

/// A proposed value for one field, in one Store Page language or App
/// Information page, with a reason. It never changes the field by itself:
/// the person accepts, edits or dismisses it, and an accepted value waits
/// in Review & Push like any other change.
struct FieldSuggestion: Identifiable, Hashable, Codable, Sendable {
    /// `sg_<n>` for an assistant's or the AI provider's; built-in ones are
    /// derived from the field and value (`builtInID`), so dismissing one
    /// sticks for as long as the check finds the same thing.
    var id: String
    var appID: StoreApp.ID
    var target: SuggestionTarget
    var value: String
    /// One sentence: why this value.
    var reason: String
    var source: SuggestionSource
    var evidence: [SuggestionEvidence] = []
    /// Details, how sure and a gloss, when the assistant sent them; nil in
    /// data saved before they existed.
    var layers: SuggestionLayers?
    var createdAt: Date
    /// Why the assistant sent it, when Atlas started the run for a reason of
    /// its own (a Look for Improvements run's id); nil for every other
    /// suggestion and in data saved before it existed.
    var origin: ChangeOrigin?

    init(
        id: String,
        appID: StoreApp.ID,
        target: SuggestionTarget,
        value: String,
        reason: String,
        source: SuggestionSource,
        evidence: [SuggestionEvidence] = [],
        layers: SuggestionLayers? = nil,
        createdAt: Date = .now,
        origin: ChangeOrigin? = nil
    ) {
        self.id = id
        self.appID = appID
        self.target = target
        self.value = value
        self.reason = reason
        self.source = source
        self.evidence = evidence
        self.layers = layers
        self.createdAt = createdAt
        self.origin = origin
    }

    /// When an assistant or the AI provider's suggestion came, for its
    /// arrival (effect 2). Built-in checks are worked out again whenever
    /// the page is, so they never arrive: nil.
    var arrivedAt: Date? {
        source == .builtIn ? nil : createdAt
    }

    /// A built-in check's suggestion, with an id that stays the same as long
    /// as the check finds the same value.
    static func builtIn(appID: StoreApp.ID, target: SuggestionTarget, value: String, reason: String) -> FieldSuggestion {
        FieldSuggestion(id: builtInID(appID: appID, target: target, value: value), appID: appID, target: target, value: value, reason: reason, source: .builtIn)
    }

    /// `builtin.<app>.<target>.<hash>`, with an FNV-1a hash of the value:
    /// Swift's `hashValue` changes from launch to launch.
    static func builtInID(appID: StoreApp.ID, target: SuggestionTarget, value: String) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return "builtin.\(appID).\(target.id).\(String(hash, radix: 36))"
    }
}
