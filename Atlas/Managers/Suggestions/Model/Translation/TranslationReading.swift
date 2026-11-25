//
//  TranslationReading.swift
//  Atlas
//

import Foundation

/// The assistant's second read of a suggestion in another language, as a
/// native speaker (board 77): how natural it sounds, the phrases that read
/// like a translation, and a natural version of the whole text. What it
/// means (MEANS) is the layers' `gloss`. All optional; a suggestion sent
/// without them shows MEANS only, or nothing new.
struct TranslationReading: Hashable, Codable, Sendable {
    var sounds: SoundsNatural?
    /// In the order the assistant sent them; cards show the first two.
    var notes: [TranslationNote]
    /// The whole text as a native speaker would write it, for Use Natural
    /// Version.
    var natural: String?
    /// What the natural version means, in the interface language: MEANS
    /// once it's on the card.
    var naturalMeans: String?
    /// Words in MEANS that moved away from the original.
    var drift: [MeaningDrift]
    /// Set while the natural version is on the card: what Undo puts back.
    var original: TranslationOriginal?

    /// Notes a card lists under the Sounds line.
    static let shownNoteCount = 2

    init(
        sounds: SoundsNatural? = nil,
        notes: [TranslationNote] = [],
        natural: String? = nil,
        naturalMeans: String? = nil,
        drift: [MeaningDrift] = [],
        original: TranslationOriginal? = nil
    ) {
        self.sounds = sounds
        self.notes = notes.filter { !$0.phrase.isEmpty && !$0.natural.isEmpty }
        self.natural = Self.cleaned(natural)
        self.naturalMeans = Self.cleaned(naturalMeans)
        self.drift = drift.filter { !$0.phrase.isEmpty }
        self.original = original
    }

    var isEmpty: Bool {
        sounds == nil && notes.isEmpty && natural == nil && naturalMeans == nil && drift.isEmpty && original == nil
    }

    var nonEmpty: TranslationReading? { isEmpty ? nil : self }

    /// The natural version is on the card.
    var usesNaturalVersion: Bool { original != nil }

    /// Use Natural Version (or its Undo) shows on the Sounds line.
    var offersNaturalVersion: Bool { natural != nil || original != nil }

    /// The notes the card lists: none once the natural version is on it.
    var shownNotes: [TranslationNote] {
        usesNaturalVersion ? [] : Array(notes.prefix(Self.shownNoteCount))
    }

    /// The phrases Suggested underlines.
    var markedPhrases: [String] { shownNotes.map(\.phrase) }

    /// The underlined phrases' tooltip: each one's natural version and why.
    var markHelp: String {
        shownNotes.map(Self.tooltip(for:)).joined(separator: "\n")
    }

    /// The words beside the pill on the Sounds line, worked out in Atlas
    /// from the level and the notes (no free text from the assistant).
    var summary: String? {
        if usesNaturalVersion {
            return String(localized: "The natural version. Accept takes it; nothing is sent yet.", comment: "kind:description")
        }
        guard let sounds else { return nil }
        let count = notes.count
        switch sounds {
        case .native:
            return String(localized: "Reads naturally.", comment: "kind:description")
        case .translated:
            if count == 0 { return String(localized: "Right meaning, phrased like the original.", comment: "kind:description") }
            return count == 1
                ? String(localized: "1 phrase follows the original too closely.", comment: "kind:description")
                : String(localized: "\(count) phrases follow the original too closely.", comment: "kind:description")
        case .off:
            return count > 1
                ? String(localized: "\(count) phrases change the meaning.", comment: "kind:description")
                : String(localized: "A phrase changes the meaning.", comment: "kind:description")
        }
    }

    /// The pill's tooltip, naming who judged it.
    static func tooltip(judgedBy client: String) -> String {
        String(
            localized: "How natural it reads to a native speaker, judged by \(client). For the name and subtitle, a native speaker is still the best review.",
            comment: "kind:tooltip"
        )
    }

    /// The tooltip on an underlined phrase in Suggested.
    static func tooltip(for note: TranslationNote) -> String {
        String(localized: "More natural: \(note.natural). \(note.why)", comment: "kind:tooltip")
    }

    /// The tooltip on a word MEANS underlines.
    static func tooltip(for drift: MeaningDrift) -> String {
        String(localized: "The original says “\(drift.original)”.", comment: "kind:tooltip")
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
