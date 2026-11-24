//
//  NominationsDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state a Nominations DEBUG scene opens in: which nomination or
/// suggestion is open, a confirmation sheet, a field to change first, and
/// board 70's today.
struct NominationsDebugLaunch {
    /// Taken by the section when it builds its view model.
    @MainActor static var pending: NominationsDebugLaunch?

    var selection: NominationsViewModel.Selection?
    var sheet: NominationSheet?
    /// Opens a new, empty draft.
    var opensNew = false
    /// Queues the open draft's Create row, as Add to Review & Push does.
    var addsToReviewPush = false
    /// Changes the open draft before the scene shows.
    var change: (@MainActor (inout NominationContent) -> Void)?
    var showsRefusalDetails = false

    /// Before the first read: board 70's today.
    @MainActor
    func prepare(_ model: NominationsViewModel) {
        model.now = { DebugNominationsData.now }
    }

    @MainActor
    func apply(to model: NominationsViewModel) {
        if opensNew { model.newNomination() }
        if let selection { model.selection = selection }
        if let change, let id = model.selectedNomination?.id { model.update(id, change) }
        if addsToReviewPush, let id = model.selectedNomination?.id { model.addToReviewPush(id) }
        model.showsRefusalDetails = showsRefusalDetails
        model.sheet = sheet
    }
}
#endif
