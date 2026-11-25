//
//  ProductPagesViewModel+NaturalVersion.swift
//  Atlas
//

import Foundation

// Use Natural Version on a page's suggested promotional text (board 77,
// risk level 1): the card's text becomes the natural version, with a
// toast whose Undo puts it back. Accept and Use and Edit take what's on
// the card.
extension ProductPagesViewModel {
    func useNaturalVersion(_ suggestion: ProductPageTextSuggestion) {
        guard let swapped = suggestion.layers?.usingNaturalVersion(over: suggestion.text) else { return }
        let undo = snapshotForUndo()
        replace(suggestion, text: swapped.value, layers: swapped.layers)
        show(String(localized: "The natural version is on the card. Nothing is sent yet.", comment: "kind:toast"), undo: undo)
    }

    func undoNaturalVersion(_ suggestion: ProductPageTextSuggestion) {
        guard let swapped = suggestion.layers?.undoingNaturalVersion() else { return }
        replace(suggestion, text: swapped.value, layers: swapped.layers)
        toast = nil
    }

    private func replace(_ suggestion: ProductPageTextSuggestion, text: String, layers: SuggestionLayers) {
        var changed = suggestion
        changed.text = text
        changed.layers = layers
        store.add([changed], for: app.id)
    }
}
