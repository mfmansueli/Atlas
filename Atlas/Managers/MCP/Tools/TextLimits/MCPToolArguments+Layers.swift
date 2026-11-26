//
//  MCPToolArguments+Layers.swift
//  Atlas
//

import Foundation

extension MCPToolArguments {
    /// `details`, `confidence`, `means` (or `gloss`) and the translation
    /// fields (`sounds`, `notes`, `natural`, `naturalMeans`, `drift`) as
    /// sent beside a why, or nil when none came. The server checked the
    /// text limits before the call (`AssistantTextCheck`); a confidence
    /// outside 1–3, a sounds that isn't one of its values or a note without
    /// its phrase still throws here, with the reason.
    func layers() throws -> SuggestionLayers? {
        let confidence: HowSure?
        if let number = try optionalInt("confidence") {
            guard let value = HowSure(rawValue: number) else {
                throw MCPToolError.invalidArgument(name: "confidence", expected: String(localized: "1, 2 or 3"))
            }
            confidence = value
        } else {
            confidence = nil
        }
        let means = try optionalString("means") ?? optionalString("gloss")
        return try SuggestionLayers(details: optionalString("details"), confidence: confidence, gloss: means, translation: translation()).nonEmpty
    }

    /// A batch item's own layers over the call's: its details and how sure
    /// win, else the call's; MEANS and the translation fields are only ever
    /// its own, since they say what that item's text means and how it reads.
    func layers(over call: SuggestionLayers?) throws -> SuggestionLayers? {
        let own = try layers()
        return SuggestionLayers(
            details: own?.details ?? call?.details, confidence: own?.confidence ?? call?.confidence, gloss: own?.gloss,
            translation: own?.translation
        ).nonEmpty
    }

    /// `sounds`, `notes`, `natural`, `naturalMeans` and `drift`, checked;
    /// nil when none came.
    func translation() throws -> TranslationReading? {
        let sounds: SoundsNatural?
        if let value = values["sounds"], !value.isNull {
            guard let parsed = SoundsNatural(mcpValue: value) else {
                throw MCPToolError.invalidArgument(name: "sounds", expected: String(localized: "native, translated or off"))
            }
            sounds = parsed
        } else {
            sounds = nil
        }
        let notes = try translationNotes().enumerated().map { index, entry in
            try Self.note(entry, at: index)
        }
        let drift = try (optionalArray("drift") ?? []).map { entry in
            guard let phrase = entry["phrase"]?.stringValue, let original = entry["original"]?.stringValue,
                  !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw MCPToolError.invalidArgument(name: "drift", expected: String(localized: "a list of {phrase, original} objects"))
            }
            return MeaningDrift(phrase: phrase, original: original)
        }
        let reading = try TranslationReading(
            sounds: sounds, notes: notes, natural: optionalString("natural"), naturalMeans: optionalString("naturalMeans"), drift: drift
        )
        if let problem = reading.problems().first {
            throw MCPToolError.invalidArgument(name: problem.field, expected: problem.expected)
        }
        return reading.nonEmpty
    }

    /// `notes` as translation notes: a list of {phrase, natural, why}.
    /// Tools whose own field is called `notes` (a nomination's notes, a
    /// batch of review notes) send a text or a list of other objects;
    /// those aren't translation notes and are left to the tool.
    private func translationNotes() -> [JSONValue] {
        guard let entries = values["notes"]?.arrayValue,
              entries.allSatisfy({ $0.objectValue?["phrase"] != nil })
        else { return [] }
        return entries
    }

    private static func note(_ entry: JSONValue, at index: Int) throws -> TranslationNote {
        let phrase = entry["phrase"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let natural = entry["natural"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let why = entry["why"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phrase.isEmpty, !natural.isEmpty else {
            throw MCPToolError.invalidArgument(
                name: "notes[\(index)]", expected: String(localized: "a {phrase, natural, why} object with the phrase and what to write instead")
            )
        }
        return TranslationNote(phrase: phrase, natural: natural, why: why)
    }
}
