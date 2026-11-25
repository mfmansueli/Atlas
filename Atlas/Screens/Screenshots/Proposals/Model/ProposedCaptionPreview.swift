//
//  ProposedCaptionPreview.swift
//  Atlas
//

import Foundation

/// A suggested caption drawn on its screenshot from the template, with the
/// suggestion or as the caption reads now: the language page's Suggested,
/// the Accept All sheet's before → after and the App Store preview's
/// Suggested (README-Redesign).
struct ProposedCaptionPreview {
    let document: ScreenshotsDocument
    let primaryLocale: StoreLocale
    let engine: ScreenshotLayoutEngine
    var ratings: StoreRatings = .unchecked

    /// The caption's slot drawn with it, or, when `suggested` is false,
    /// with the caption the slot has now; nil without a template or that
    /// slot.
    func preview(for caption: ProposedCaption, suggested: Bool = true, on display: ScreenshotDisplayType) -> SlotPreview? {
        guard let template = document.template, template.slots.indices.contains(caption.slot),
              let locale = StoreLocaleCatalog.locale(code: caption.locale) else { return nil }
        let current = document.captions.caption(locale: caption.locale, slot: caption.slot)
        let shown = suggested
            ? caption.item.caption(over: current, provenance: .assistant(client: caption.client, date: caption.receivedAt))
            : current
        let capture = document.captures.capture(locale: caption.locale, displayType: display, slot: caption.slot, primary: primaryLocale.code)
        let placement = SlotPreview.Placement(template: template, locale: locale, displayType: display, slot: caption.slot)
        return SlotPreview.make(
            placement, caption: shown, capture: capture, engine: engine, primaryLocaleName: primaryLocale.name, ratings: ratings
        )
    }

    /// Every slot of `locale` with a caption waiting, drawn with it, by
    /// slot.
    func suggestedSlots(locale: String, on display: ScreenshotDisplayType) -> [Int: SlotPreview] {
        var previews: [Int: SlotPreview] = [:]
        for caption in document.openProposedCaptions(in: locale) {
            previews[caption.slot] = preview(for: caption, on: display)
        }
        return previews
    }
}
