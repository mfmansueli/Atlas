//
//  PageShotsCaption.swift
//  Atlas
//

import Foundation

/// A screen's caption on the page's set in one language: a headline and,
/// where the template has room, a subhead. The default page's captions
/// stay as they are.
struct PageShotsCaption: Codable, Hashable, Sendable {
    var headline: String
    var subhead: String?

    init(headline: String, subhead: String? = nil) {
        self.headline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let subhead = subhead?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subhead = subhead?.isEmpty == false ? subhead : nil
    }

    var isEmpty: Bool { headline.isEmpty }

    /// What the layout engine draws (who wrote it doesn't change it).
    var screenshotCaption: ScreenshotCaption {
        ScreenshotCaption(headline: headline, subhead: subhead)
    }

    init(_ caption: ScreenshotCaption) {
        self.init(headline: caption.headline, subhead: caption.visibleSubhead)
    }
}
