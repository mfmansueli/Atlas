//
//  SuggestionLayers.swift
//  Atlas
//

import Foundation

/// What an assistant sends beside a suggestion's or a finding's title and
/// why (README-DS §9, "Every decision has three layers"): the details shown
/// on demand, how sure it is, and a gloss when the text is in a language
/// the person may not read. All optional; data saved before has none.
struct SuggestionLayers: Hashable, Codable, Sendable {
    /// The cause, every number, the source and the risk: behind "Details".
    var details: String?
    var confidence: HowSure?
    /// What the text means in the interface language, shown as
    /// "Means: …" under it.
    var gloss: String?

    init(details: String? = nil, confidence: HowSure? = nil, gloss: String? = nil) {
        self.details = Self.cleaned(details)
        self.confidence = confidence
        self.gloss = Self.cleaned(gloss)
    }

    var isEmpty: Bool { details == nil && confidence == nil && gloss == nil }

    /// nil when empty, so a model keeps nothing for a suggestion that came
    /// without any of them.
    var nonEmpty: SuggestionLayers? { isEmpty ? nil : self }

    private static func cleaned(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
