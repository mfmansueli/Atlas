//
//  ScreenshotsViewModel+NaturalCaptions.swift
//  Atlas
//

import Foundation

// Use Natural Version on a suggested caption (board 77, risk level 1): a
// toast with Undo, and Undo on the card.
extension ScreenshotsViewModel {
    func useNaturalCaption(_ caption: ProposedCaption) async {
        await swapNaturalCaption(caption, undo: false)
    }

    func undoNaturalCaption(_ caption: ProposedCaption) async {
        await swapNaturalCaption(caption, undo: true)
    }

    private func swapNaturalCaption(_ caption: ProposedCaption, undo: Bool) async {
        guard var document else { return }
        let before = document
        guard document.swapNaturalCaption(caption.id, undo: undo) else { return }
        await commit(document)
        if undo {
            captionToast = nil
            captionUndo = nil
            return
        }
        captionUndo = { [weak self] in await self?.commit(before) }
        captionToast = ToastMessage(
            text: String(localized: "Screenshot \(caption.slot + 1): the natural caption is on the card. Nothing is sent yet.", comment: "kind:toast"),
            canUndo: true
        )
    }
}
