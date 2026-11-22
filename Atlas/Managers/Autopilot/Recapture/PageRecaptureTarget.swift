//
//  PageRecaptureTarget.swift
//  Atlas
//

import Foundation

/// A custom product page's screens the assistant asked to capture again
/// (`request_page_recapture`): the default set's slots, in one language on
/// one device, at most `PageShotsRecapture.maxScreens`.
struct PageRecaptureTarget: Codable, Hashable, Sendable {
    var pageID: ProductPage.ID
    var pageName: String
    /// The default set's slots, 0-based.
    var slots: [Int]
    var locale: String
    var displayType: ScreenshotDisplayType

    /// The same page, by ID or by name.
    func isSamePage(as other: PageRecaptureTarget) -> Bool {
        pageID == other.pageID || ProductPageBrief.key(pageName) == ProductPageBrief.key(other.pageName)
    }
}
