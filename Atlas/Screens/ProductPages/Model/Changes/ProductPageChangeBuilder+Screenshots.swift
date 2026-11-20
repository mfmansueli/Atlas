//
//  ProductPageChangeBuilder+Screenshots.swift
//  Atlas
//

import Foundation

/// A page's own screenshots (board 52): one change per language and
/// device, uploading the PNGs Make Screenshots for This Page laid out into
/// the page's set of that device. Nothing restores them: the default
/// page's screenshots are untouched, and a page's old set is replaced.
extension ProductPageChangeBuilder {
    func screenshotsChangeID(pageID: ProductPage.ID, locale: String, displayType: ScreenshotDisplayType) -> String {
        "\(idPrefix)\(pageID).\(locale).\(displayType.rawValue).\(ProductPageField.screenshots.rawValue)"
    }

    /// One language's screenshots on one device, in their order.
    func screenshotsChange(
        _ files: [ProductPageScreenshotsPush.File], locale: String, displayType: ScreenshotDisplayType, of page: ProductPage,
        hadOwn: Bool, source: ChangeSource = .you
    ) -> PendingChange {
        let push = ProductPageScreenshotsPush(.init(
            appID: appID, pageID: page.id, pageName: page.name, currentDeepLink: page.deepLink, locale: locale, displayType: displayType,
            files: files
        ))
        return PendingChange(
            id: screenshotsChangeID(pageID: page.id, locale: locale, displayType: displayType),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: "\(Self.localeName(locale)) · \(ProductPageField.screenshots.title) · \(displayType.shortTitle)",
            flagRegion: Self.region(locale),
            oldValue: hadOwn ? String(localized: "The page’s own screenshots") : String(localized: "The default page’s screenshots"),
            newValue: files.count == 1 ? String(localized: "1 screenshot made for this page") : String(localized: "\(files.count) screenshots made for this page"),
            source: source,
            blockedReason: files.isEmpty || files.count > ProductPageScreenshotsPush.maxScreenshots
                ? String(localized: "A set has 1 to 10 screenshots.") : nil,
            requests: [push.request], restoreRequests: []
        )
    }

    /// Whether a queued change is a page's own screenshots.
    func isScreenshotsChange(_ change: PendingChange) -> Bool {
        owns(change) && change.id.hasSuffix(".\(ProductPageField.screenshots.rawValue)")
    }

    /// The page's own screenshots queued, for its ID or, once a draft is in
    /// App Store Connect, for its name.
    func screenshotChanges(pageID: ProductPage.ID, pageName: String, in changes: [PendingChange]) -> [PendingChange] {
        changes.filter { change in
            guard isScreenshotsChange(change) else { return false }
            if isChange(change, of: pageID) { return true }
            let content = change.requests.lazy.compactMap(ProductPageScreenshotsPush.init).first?.content
            return content.map { ProductPageBrief.key($0.pageName) == ProductPageBrief.key(pageName) } ?? false
        }
    }

    /// A screenshots change's language, device and files into `edits`.
    func addScreenshots(of change: PendingChange, to edits: inout ProductPageEdits) {
        guard let content = change.requests.lazy.compactMap(ProductPageScreenshotsPush.init).first?.content else { return }
        edits.screenshots[content.locale, default: [:]][content.displayType] = content.files
    }
}
