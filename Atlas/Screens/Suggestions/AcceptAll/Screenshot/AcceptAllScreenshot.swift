//
//  AcceptAllScreenshot.swift
//  Atlas
//

import Foundation

/// A suggested caption's screenshot in the Accept All sheet: its slot drawn
/// from the template with the caption it has now, and with the suggested
/// one (README-Redesign, Accept All Languages: "Screenshots show the
/// screenshot before and after").
struct AcceptAllScreenshot: Hashable, Sendable {
    var now: SlotPreview
    var suggested: SlotPreview

    /// Both, or nil when either can't be drawn (no template or no slot).
    static func make(now: SlotPreview?, suggested: SlotPreview?) -> AcceptAllScreenshot? {
        guard let now, let suggested else { return nil }
        return AcceptAllScreenshot(now: now, suggested: suggested)
    }
}
