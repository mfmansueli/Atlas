//
//  SuggestedPreviewShots.swift
//  Atlas
//

import Foundation

/// The App Store preview's Suggested on the screenshots (README-Redesign,
/// “Now | Suggested”): each screenshot of the set the row shows whose
/// caption an assistant suggested, drawn by the template engine with that
/// caption, to show in a purple ring in place of the live image. A
/// language without screenshots of its own shows the primary language's,
/// and so its suggestions.
struct SuggestedPreviewShots: Equatable {
    /// The language whose set the row shows.
    var locale: String
    var displayType: ScreenshotDisplayType
    /// By position in the row: the slot drawn with its suggested caption.
    var previews: [Int: SlotPreview]

    static let none = SuggestedPreviewShots(locale: "", displayType: .iPhone, previews: [:])

    var count: Int { previews.count }

    func preview(at position: Int) -> SlotPreview? {
        previews[position]
    }

    /// The suggestions on the set `live` shows in `locale` (an iPhone set
    /// when there is one, else the primary language's), from `document`'s
    /// template and captures. None without a set, a template or captions
    /// waiting; never more than the set has screenshots.
    @MainActor
    static func make(
        document: ScreenshotsDocument?,
        live: LiveScreenshots,
        locale: StoreLocale,
        primary: StoreLocale,
        engine: ScreenshotLayoutEngine
    ) -> SuggestedPreviewShots {
        guard let document, document.template != nil,
              let set = PreviewShotsStrip.bestSet(in: live, locale: locale) ?? PreviewShotsStrip.bestSet(in: live, locale: primary)
        else { return .none }
        let drawn = ProposedCaptionPreview(document: document, primaryLocale: primary, engine: engine)
            .suggestedSlots(locale: set.locale, on: set.displayType)
            .filter { set.screenshots.indices.contains($0.key) }
        return SuggestedPreviewShots(locale: set.locale, displayType: set.displayType, previews: drawn)
    }

    /// Added to the row's VoiceOver label: "3 captions suggested".
    var accessibilityText: String? {
        switch count {
        case 0: nil
        case 1: String(localized: "1 caption suggested")
        default: String(localized: "\(count) captions suggested")
        }
    }
}
