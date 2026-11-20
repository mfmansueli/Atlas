//
//  ProductPagesViewModel+PageShots.swift
//  Atlas
//

import Foundation

// Make Screenshots for This Page (board 52) from the editor: the flow of
// the page, and the set queued in Review & Push shown as the page's own.
extension ProductPagesViewModel {
    /// The languages a page's set can be made in: the default page's,
    /// primary first.
    var pageShotsLanguages: [String] {
        [primaryLocale] + defaultPage.locales.filter { $0 != primaryLocale }
    }

    /// Who the page is for: the draft's note, else its brief's audience.
    func pageShotsNote(of page: ProductPage) -> String {
        if let note = draft(of: page)?.note.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { return note }
        return brief(of: page)?.audience ?? ""
    }

    /// The flow for `page`: the open one, or a new one.
    func pageShotsFlow(for page: ProductPage) -> PageShotsFlow? {
        if let pageShots, pageShots.page.id == page.id { return pageShots }
        let flow = makePageShotsFlow?(page)
        pageShots = flow
        return flow
    }

    /// Make Screenshots for This Page…, or Show on a run under way.
    func openPageShots(_ page: ProductPage) async {
        await pageShotsFlow(for: page)?.open()
    }

    /// The page's own screenshots queued for a language on a device, in
    /// their order; nil when none are.
    func queuedScreenshots(of page: ProductPage, locale: String, device: ProductPageDevice) -> [ProductPageScreenshotsPush.File]? {
        let queued = builder.screenshotChanges(pageID: page.id, pageName: page.name, in: queue.changes(for: app.id, section: .productPages))
        return queued.lazy
            .compactMap { $0.requests.lazy.compactMap(ProductPageScreenshotsPush.init).first?.content }
            .first { $0.locale == locale && device.matches($0.displayType.apiValue) }?
            .files
    }

    /// The page's run, from Make Screenshots for This Page…
    func pageShotsRun(of page: ProductPage) -> PageShotsRun? {
        pageShotsStudio.run(appID: app.id, pageName: page.name)
    }

    /// Whether any of the page's own screenshots are queued.
    func hasQueuedScreenshots(_ page: ProductPage) -> Bool {
        !builder.screenshotChanges(pageID: page.id, pageName: page.name, in: queue.changes(for: app.id, section: .productPages)).isEmpty
    }
}
