//
//  InAppEventsArchive.swift
//  Atlas
//

import Foundation

/// What `InAppEventsStore` keeps for one app.
struct InAppEventsArchive: Hashable, Codable, Sendable {
    var suggestions: [InAppEventTextSuggestion] = []
    /// Ids of the suggestions the person dismissed.
    var dismissed: Set<String> = []

    /// The suggestions still waiting.
    var open: [InAppEventTextSuggestion] {
        suggestions.filter { !dismissed.contains($0.id) }
    }
}
