//
//  ProductPagesDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a Custom Product Pages DEBUG scene opens with, applied once the
/// section has read the sample pages.
struct ProductPagesDebugLaunch {
    @MainActor static var pending: ProductPagesDebugLaunch?

    typealias PageID = DebugProductPagesData.PageID

    /// The page the editor opens on; nil shows the list.
    var pageID: ProductPage.ID?
    var locale = "en-US"
    var device = ProductPageDevice.iPhone
    var expandedSuggestionID: String?
    var opensNewPage = false
    var newPage: NewProductPage?
    var confirmation: ProductPageConfirmation?
    /// Private diary as if pushed, its first version in this state; the
    /// draft and its change are gone.
    var pushedPrivateDiary: ProductPageState?
    var opensSubmit = false
    /// Edit… pressed, with these changes queued.
    var editsApproved: [PendingChange] = []
    /// Offline after the first read.
    var failure: String?
    /// Make Screenshots for This Page (board 52): the page's flow at this
    /// stage, its sheet open unless it's in Review & Push already.
    var pageShots: PageShotsStage?

    @MainActor
    func apply(to model: ProductPagesViewModel) {
        if let failure { model.setDebugState(failure: failure) }
        if let state = pushedPrivateDiary, var snapshot = model.snapshot {
            model.queue.discard(id: model.builder.newPageChangeID(draftID: PageID.privateDiary))
            model.store.removeDrafts([PageID.privateDiary], for: model.app.id)
            snapshot.pages.append(DebugProductPagesData.pushedPrivateDiary(state))
            model.replaceSnapshot(snapshot)
        }
        if !editsApproved.isEmpty {
            model.queue.upsert(contentsOf: editsApproved)
            if let pageID { model.startNewVersion(of: model.page(pageID) ?? DebugProductPagesData.pages[0]) }
        }
        model.expandedSuggestionID = expandedSuggestionID
        model.device = device
        if let pageID {
            model.open(pageID)
            model.localeCode = locale
        }
        model.newPageTemplate = newPage
        model.isNewPagePresented = opensNewPage
        model.confirmation = confirmation
        model.isSubmitPresented = opensSubmit
        if let stage = pageShots, let pageID, let page = model.page(pageID) {
            PageShotsDebugSetup.pending = PageShotsDebugSetup(stage: stage)
            if stage == .used {
                _ = model.pageShotsFlow(for: page)
            } else {
                Task { await model.openPageShots(page) }
            }
        }
    }
}
#endif
