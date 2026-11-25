//
//  StoreArtworkSlot.swift
//  Atlas
//

import Foundation

/// One language's header or search artwork on the Screenshots page: what's
/// live, what waits in Review & Push, the state that makes, what the tile
/// draws (the space never disappears: no header is a dashed box, no search
/// artwork is screenshots 1–3) and what its menu offers.
struct StoreArtworkSlot: Hashable, Identifiable {
    /// What the tile draws.
    enum Content: Hashable {
        /// What App Store Connect shows.
        case live(LiveArtworkImage)
        /// A file waiting in Review & Push.
        case file(ExtrasArtworkFile)
        /// No header: the page starts with the icon and name.
        case noHeader
        /// No search artwork: search shows screenshots 1–3.
        case searchShots
    }

    let place: StoreArtworkPlace
    let locale: String
    let live: LiveArtworkImage?
    /// The made or given file waiting to go.
    let pending: ExtrasArtworkFile?
    let removal: ExtrasArtworkRemoval?

    init(place: StoreArtworkPlace, locale: String, live: LiveArtworkImage?, extras: ScreenshotExtras?) {
        self.place = place
        self.locale = locale
        self.live = live
        pending = extras?.pendingArtwork(place, locale: locale)
        removal = extras?.removal(place, locale: locale)
    }

    var id: String { "\(place.rawValue)-\(locale)" }

    var state: StoreArtworkState {
        if removal != nil, live != nil { return .willBeDeleted }
        if pending != nil { return live == nil ? .new : .replaced }
        return live == nil ? .none : .live
    }

    /// The tile: the file waiting, else what's live (dimmed while it's to
    /// be deleted), else what Apple shows instead.
    var content: Content {
        if state != .willBeDeleted, let pending { return .file(pending) }
        if let live { return .live(live) }
        return place == .header ? .noHeader : .searchShots
    }

    /// What the App Store preview draws after the next push; nil shows no
    /// header, or screenshots 1–3 in search.
    var storeContent: Content? {
        guard state.showsOnStore else { return nil }
        return content
    }

    /// Add ▾ when there's nothing, else Edit ▾.
    var buttonTitle: String {
        state == .none
            ? String(localized: "Add", comment: "kind:button")
            : String(localized: "Edit", comment: "kind:button")
    }

    var menuItems: [StoreArtworkMenuItem] { StoreArtworkMenuItem.items(for: self) }

    /// "Header, German, Replaced · not pushed".
    func accessibilityLabel(localeName: String) -> String {
        [place.title, localeName, state.title(for: place)].joined(separator: ", ")
    }
}
