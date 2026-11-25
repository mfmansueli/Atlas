//
//  SuggestionLayers+NaturalVersion.swift
//  Atlas
//

import Foundation

// Use Natural Version (board 77, risk level 1): the natural text goes on
// the card and MEANS says what it means; Undo puts the assistant's first
// text back. Accept and Use and Edit take what's on the card. Nothing
// leaves Atlas before the push.
extension SuggestionLayers {
    /// The card with the natural version over `value`, or nil when there's
    /// none to use (or it's on already).
    func usingNaturalVersion(over value: String) -> (value: String, layers: SuggestionLayers)? {
        guard var translation, translation.original == nil, let natural = translation.natural, natural != value else { return nil }
        translation.original = TranslationOriginal(text: value, means: gloss, sounds: translation.sounds)
        translation.sounds = .native
        var layers = self
        layers.gloss = translation.naturalMeans
        layers.translation = translation
        return (natural, layers)
    }

    /// The card as the assistant sent it, or nil when the natural version
    /// isn't on it.
    func undoingNaturalVersion() -> (value: String, layers: SuggestionLayers)? {
        guard var translation, let original = translation.original else { return nil }
        translation.sounds = original.sounds
        translation.original = nil
        var layers = self
        layers.gloss = original.means
        layers.translation = translation
        return (original.text, layers)
    }

    /// What Accept All Languages does with it: anything but Sounds off
    /// starts ticked; without asking it never takes a Sounds off.
    var soundsOff: Bool {
        translation?.usesNaturalVersion == false && translation?.sounds == .off
    }
}
