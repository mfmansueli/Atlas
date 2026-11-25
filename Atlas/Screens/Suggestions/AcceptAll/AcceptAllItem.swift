//
//  AcceptAllItem.swift
//  Atlas
//

import Foundation

/// One suggestion in the Accept All sheet: which field, who suggested it and
/// why, and what it replaces; a caption also shows its screenshot before
/// and after.
struct AcceptAllItem: Identifiable, Hashable, Sendable {
    /// The suggestion's id.
    let id: String
    /// "Keywords", "Apple Watch · VoiceOver", "Screenshot 2 · caption".
    var title: String
    var source: SuggestionSource
    /// What the field holds now; "" reads "Empty".
    var current: String
    var suggested: String
    var reason: String
    /// A screenshot caption's slot, drawn now and with the suggestion.
    var screenshot: AcceptAllScreenshot?
    /// Board 77: what it says in the interface language (MEANS under New)
    /// and how natural it sounds, for a language that isn't the interface's.
    var means: String?
    var sounds: SoundsNatural?
    /// For one that sounds off: its first note, said as why it's left out.
    var soundsOffReason: String?

    /// Sounds off: starts unticked, and Accept All Languages without asking
    /// leaves it for the person.
    var soundsOff: Bool { sounds == .off }

    /// MEANS and the Sounds pill for `layers`, when `lines` shows them.
    func reading(_ layers: SuggestionLayers?, lines: TranslationLines) -> AcceptAllItem {
        var item = self
        item.means = lines.showsMeans ? layers?.means : nil
        guard lines.showsSounds, let translation = layers?.translation else { return item }
        item.sounds = translation.sounds
        if translation.sounds == .off, !translation.usesNaturalVersion {
            item.soundsOffReason = translation.notes.first.map { note in
                String(localized: "“\(note.phrase)” → “\(note.natural)”: \(note.why) Left out; review it on its page.", comment: "kind:description")
            } ?? String(localized: "It sounds off to a native speaker. Left out; review it on its page.", comment: "kind:description")
        }
        return item
    }
}
