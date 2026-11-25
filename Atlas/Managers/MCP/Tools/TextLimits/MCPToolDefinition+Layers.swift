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
    /// `gloss` and the translation fields (`translationProperties`) for a
    /// text in another language; `natural: false` leaves `natural` out
    /// where one text can't stand for the item (an event's three).
    static func withLayers(_ properties: [String: JSONValue], gloss: Bool = false, natural: Bool = true) -> [String: JSONValue] {
        var properties = properties
        properties["details"] = detailsProperty
        properties["confidence"] = confidenceProperty
        if gloss { properties.merge(translationProperties(natural: natural)) { _, new in new } }
        return properties
    }

    /// `properties` with `confidence`, for a tool that sends no why line
    /// (so no details either), and `gloss` and the translation fields for
    /// a text in another language.
    static func withConfidence(_ properties: [String: JSONValue], gloss: Bool = false, natural: Bool = true) -> [String: JSONValue] {
        var properties = properties
        properties["confidence"] = confidenceProperty
        if gloss { properties.merge(translationProperties(natural: natural)) { _, new in new } }
        return properties
    }

    // MARK: - Translations (board 77)

    /// What a tool's description says about the translation fields.
    static let translationText = """
    For a text not in the person's interface language, add means (what it says, at most \(AssistantTextLimits.means) \
    characters), and from a second read as a native speaker: sounds (native, translated or off), notes \
    [{phrase, natural, why}] for the phrases that read like a translation, and natural, the whole text as a native \
    speaker writes it, checked like the text. Atlas shows them as MEANS and Sounds on the card.
    """

    static let meansProperty = string("""
    Optional, when the text isn't in the person's interface language (get_settings; English when unsure): what it \
    says, translated back, at most \(AssistantTextLimits.means) characters. Shown as the card's MEANS line. Same as \
    gloss, which older calls send; send one of them.
    """)

    /// `sounds`: how natural it reads to a native speaker.
    static let soundsProperty: JSONValue = [
        "type": "string",
        "enum": .array(SoundsNatural.allCases.map { .string($0.rawValue) }),
        "description": """
        Optional, when the text isn't in the interface language: how natural it reads to a native speaker, judged on a \
        second read as one: native (reads as if written in the language), translated (right meaning, said the way the \
        original says it) or off (a word changes the meaning, or there's a mistake). Shown as Sounds native, Sounds \
        translated or Sounds off. Accept All Languages leaves an off text unticked and never accepts it without asking.
        """,
    ]

    static let notesProperty: JSONValue = [
        "type": "array",
        "description": .string("""
        Optional, with sounds translated or off: the phrases that read like a translation, most important first (the \
        card shows 2). phrase exactly as it is in the text, natural what a native speaker writes instead, why one \
        sentence (at most \(AssistantTextLimits.why) characters, e.g. "English word order.").
        """),
        "items": schema(
            [
                "phrase": string("The phrase exactly as the text has it."),
                "natural": string("What a native speaker writes instead."),
                "why": shortWhy("Why it reads like a translation."),
            ],
            required: ["phrase", "natural", "why"]
        ),
    ]

    static let naturalProperty = string("""
    Optional, with sounds translated or off: the whole text as a native speaker would write it, within the same \
    field limit and App Review rules as the text (checked the same way; a natural that breaks one refuses the item). \
    The card offers Use Natural Version, which swaps it in; the person decides.
    """)

    static let naturalMeansProperty = string("""
    Optional, with natural: what the natural version says, at most \(AssistantTextLimits.means) characters; MEANS \
    once it's on the card.
    """)

    static let driftProperty: JSONValue = [
        "type": "array",
        "description": """
        Optional, with sounds off: the words in means that moved away from the original, each {phrase (exactly as means \
        has it), original (what the original says there)}. MEANS underlines them.
        """,
        "items": schema(
            ["phrase": string("The word as means has it."), "original": string("What the original says there.")],
            required: ["phrase", "original"]
        ),
    ]

    /// `gloss`, `means`, `sounds`, `notes`, `natural`, `naturalMeans` and
    /// `drift`: what a card shows about a text in another language.
    static func translationProperties(natural: Bool = true) -> [String: JSONValue] {
        var properties: [String: JSONValue] = [
            "gloss": glossProperty,
            "means": meansProperty,
            "sounds": soundsProperty,
            "notes": notesProperty,
            "drift": driftProperty,
        ]
        if natural {
            properties["natural"] = naturalProperty
            properties["naturalMeans"] = naturalMeansProperty
        }
        return properties
    }
}
