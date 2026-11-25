//
//  AppStorePreviewArtwork.swift
//  Atlas
//

import Foundation

/// What the App Store preview draws of a language's header and search
/// artwork (board 78, app-wide): the header at the top of the page when
/// the language has one, and in the "In search results" card the search
/// artwork, or screenshots 1–3 without it. A change waiting in Review &
/// Push shows as it will be, marked Not pushed.
struct AppStorePreviewArtwork: Hashable {
    var locale: String
    var header: StoreArtworkSlot
    var search: StoreArtworkSlot
    /// Screenshots 1–3 on iPhone, which search shows without artwork.
    var searchShots: [LiveScreenshot]

    init(locale: String, live: LiveStoreArtworkSet, extras: ScreenshotExtras?, searchShots: [LiveScreenshot]) {
        self.locale = locale
        header = StoreArtworkSlot(place: .header, locale: locale, live: live.image(.header, locale: locale), extras: extras)
        search = StoreArtworkSlot(place: .search, locale: locale, live: live.image(.search, locale: locale), extras: extras)
        self.searchShots = searchShots
    }

    /// Nil when the page starts with the icon and name.
    var headerContent: StoreArtworkSlot.Content? { header.storeContent }

    /// Nil when search shows screenshots 1–3.
    var searchContent: StoreArtworkSlot.Content? { search.storeContent }

    /// The line under the search card.
    var searchNote: String {
        searchContent == nil
            ? String(localized: "No search artwork, so search shows screenshots 1–3.", comment: "kind:label")
            : String(localized: "Where Apple shows artwork in search. Elsewhere, screenshots 1–3.", comment: "kind:label")
    }

    /// Screenshots 1–3 of the iPhone set `locale` shows (the primary
    /// language's when it has none).
    static func searchShots(in live: LiveScreenshots, locale: StoreLocale, primary: StoreLocale) -> [LiveScreenshot] {
        let ownSet = live.set(locale: locale.code, displayType: .iPhone)
        let set = ownSet ?? live.set(locale: primary.code, displayType: .iPhone)
        return Array((set?.screenshots ?? []).prefix(StoreArtworkRules.searchShotCount))
    }
}
