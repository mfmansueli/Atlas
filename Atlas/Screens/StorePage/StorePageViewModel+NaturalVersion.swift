//
//  StorePageViewModel+NaturalVersion.swift
//  Atlas
//

import Foundation

// Board 77's Use Natural Version on a Store Page suggestion: the card's
// text becomes the natural version (risk level 1: a toast with Undo, and
// Undo on the card). Accept and Use and Edit take what's on the card;
// nothing is sent before the push.
extension StorePageViewModel {
    func useNaturalVersion(_ suggestion: FieldSuggestion) {
        guard let (field, _) = storeField(of: suggestion), suggestions.useNaturalVersion(suggestion.id) != nil else { return }
        let message = ToastMessage(
            text: String(localized: "\(field.title): the natural version is on the card. Nothing is sent yet.", comment: "kind:toast"),
            canUndo: true
        )
        toast = message
        naturalVersionUndo = (message.id, suggestion.id)
    }

    /// The card's Undo, or the toast's.
    func undoNaturalVersion(_ suggestion: FieldSuggestion) {
        undoNaturalVersion(id: suggestion.id)
    }

    func undoNaturalVersion(id: FieldSuggestion.ID) {
        suggestions.undoNaturalVersion(id)
        if naturalVersionUndo?.suggestionID == id {
            if naturalVersionUndo?.toastID == toast?.id { toast = nil }
            naturalVersionUndo = nil
        }
    }
}
