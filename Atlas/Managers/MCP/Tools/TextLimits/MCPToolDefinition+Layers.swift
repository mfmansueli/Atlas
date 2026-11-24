//
//  MCPToolDefinition+Layers.swift
//  Atlas
//

import Foundation

/// The schema properties for a card's layers (README-DS §9): the why line,
/// details on demand, how sure, and a gloss for text in another language.
/// `AssistantTextCheck` enforces the limits they state.
extension MCPToolDefinition {
    /// A `why` or `reason` property: the card's why line, with its limit.
    static func why(_ description: String) -> JSONValue {
        string(description + " " + whyLimitText)
    }

    /// A `why` or `reason` on a tool that keeps no details: one sentence
    /// within the same limit.
    static func shortWhy(_ description: String) -> JSONValue {
        string(description + " One sentence, at most \(AssistantTextLimits.why) characters.")
    }

    /// What every `why` and `reason` says about its limit.
    static let whyLimitText = """
    One sentence, the strongest evidence, at most \(AssistantTextLimits.why) characters \
    (“9 of your last 220 reviews call it too expensive.”); the rest goes in details.
    """

    static let detailsProperty = string("""
    Optional: the cause, every number, the source and the risk, shown on demand under Details. At most \
    \(AssistantTextLimits.details) characters.
    """)

    static let confidenceProperty: JSONValue = [
        "type": "integer",
        "minimum": .int(AssistantTextLimits.confidence.lowerBound),
        "maximum": .int(AssistantTextLimits.confidence.upperBound),
        "description": "Optional: how sure you are, 1 (not very sure), 2 (fairly sure) or 3 (sure). Shown as a small meter.",
    ]

    static let glossProperty = string("""
    Optional, when the text isn't in English: what it means in English, at most \(AssistantTextLimits.gloss) characters, \
    shown as “Means: …” under it.
    """)

    /// `properties` with `details` and `confidence` beside its why, and
    /// `gloss` for a text in another language.
    static func withLayers(_ properties: [String: JSONValue], gloss: Bool = false) -> [String: JSONValue] {
        var properties = properties
        properties["details"] = detailsProperty
        properties["confidence"] = confidenceProperty
        if gloss { properties["gloss"] = glossProperty }
        return properties
    }

    /// `properties` with `confidence`, for a tool that sends no why line
    /// (so no details either), and `gloss` for a text in another language.
    static func withConfidence(_ properties: [String: JSONValue], gloss: Bool = false) -> [String: JSONValue] {
        var properties = properties
        properties["confidence"] = confidenceProperty
        if gloss { properties["gloss"] = glossProperty }
        return properties
    }
}
