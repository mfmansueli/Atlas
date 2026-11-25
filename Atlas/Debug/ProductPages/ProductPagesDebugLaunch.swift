//
//  ProductPagesDebugLaunch.swift
//  Atlas
//

#if DEBUG
import CoreGraphics
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
    /// Push and Submit… pressed: Review & Push on the open page's changes.
    var opensReview = false
    /// Edit… pressed, with these changes queued.
    var editsApproved: [PendingChange] = []
    /// Offline after the first read.
    var failure: String?
    /// Make Screenshots for This Page (board 52): the page's flow at this
    /// stage, its sheet open unless it's in Review & Push already.
    var pageShots: PageShotsStage?
    /// Plan with a new look from Claude Design: drawing, or three drawn
    /// and screens captured again.
    var pageShotsLooks: PageShotsDebugSetup.Looks?
    /// Choose Files… with these sizes for the open page's language (board
    /// 52's "not drawn"): blank PNGs, checked and queued as if chosen.
    var chosenSizes: [PixelSize] = []

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
        if !chosenSizes.isEmpty, let pageID, let page = model.page(pageID) {
            let files = chosenSizes.enumerated().map { index, size in
                let data = Self.blankPNG(size) ?? Foundation.Data()
                return ProductPageChosenFile(fileName: "Screen \(index + 1).png", data: data, pixelSize: ProductPagesViewModel.pixelSize(of: data))
            }
            model.addChosenFiles(files, for: page, locale: locale)
        }
        if let stage = pageShots, let pageID, let page = model.page(pageID) {
            PageShotsDebugSetup.pending = PageShotsDebugSetup(stage: stage, looks: pageShotsLooks)
            if stage == .used {
                _ = model.pageShotsFlow(for: page)
            } else {
                Task { await model.openPageShots(page) }
            }
        }
    }

    /// A light grey PNG of `size`, for Choose Files… scenes.
    static func blankPNG(_ size: PixelSize) -> Foundation.Data? {
        guard let context = CGContext(
            data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 0.86, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage().flatMap(ScreenshotPNG.data)
    }
}
#endif
