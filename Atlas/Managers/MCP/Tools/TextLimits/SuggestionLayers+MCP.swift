//
//  SuggestionLayers+MCP.swift
//  Atlas
//

import Foundation

extension SuggestionLayers {
    /// `details`, `confidence`, `gloss` (and `means`, the same text) and
    /// the translation fields as the get_ tools list them beside a
    /// suggestion's reason; only those it has. `usesNatural` says the
    /// person put the natural version on the card.
    var mcpFields: [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        if let details { fields["details"] = .string(details) }
        if let confidence { fields["confidence"] = .int(confidence.rawValue) }
        if let gloss {
            fields["gloss"] = .string(gloss)
            fields["means"] = .string(gloss)
        }
        if let translation {
            if let sounds = translation.sounds { fields["sounds"] = .string(sounds.rawValue) }
            if !translation.notes.isEmpty {
                fields["notes"] = .array(translation.notes.map { ["phrase": .string($0.phrase), "natural": .string($0.natural), "why": .string($0.why)] })
            }
            if let natural = translation.natural { fields["natural"] = .string(natural) }
            if let naturalMeans = translation.naturalMeans { fields["naturalMeans"] = .string(naturalMeans) }
            if !translation.drift.isEmpty {
                fields["drift"] = .array(translation.drift.map { ["phrase": .string($0.phrase), "original": .string($0.original)] })
            }
            if translation.usesNaturalVersion { fields["usesNatural"] = true }
        }
        return fields
    }

    /// Puts them into a get_ tool's entry for the suggestion.
    func add(to entry: inout [String: JSONValue]) {
        entry.merge(mcpFields) { _, new in new }
    }
}
