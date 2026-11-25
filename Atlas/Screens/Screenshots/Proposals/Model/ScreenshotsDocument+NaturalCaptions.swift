//
//  ScreenshotsDocument+NaturalCaptions.swift
//  Atlas
//

import Foundation

// Board 77's Use Natural Version on a caption still waiting: its headline
// becomes the assistant's natural version and MEANS what that means;
// Undo puts the first headline back. Accept takes what's on the card.
extension ScreenshotsDocument {
    /// Swaps the waiting caption with this id (`ProposedCaption.id`) to
    /// its natural version, or back with `undo`. Returns whether it changed.
    @discardableResult
    mutating func swapNaturalCaption(_ id: String, undo: Bool = false) -> Bool {
        for index in proposals.indices where proposals[index].isWaiting && proposals[index].kind == .captions {
            let proposalID = proposals[index].id
            guard let itemIndex = proposals[index].captions.firstIndex(where: { item in
                item.decision == nil && ProposedCaption.makeID(proposalID: proposalID, key: item.key) == id
            }) else { continue }
            let item = proposals[index].captions[itemIndex]
            let layers = SuggestionLayers(gloss: item.gloss, translation: item.translation)
            guard let swapped = undo ? layers.undoingNaturalVersion() : layers.usingNaturalVersion(over: item.headline) else { return false }
            proposals[index].captions[itemIndex].headline = swapped.value
            proposals[index].captions[itemIndex].gloss = swapped.layers.gloss
            proposals[index].captions[itemIndex].translation = swapped.layers.translation
            return true
        }
        return false
    }
}
